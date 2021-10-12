defmodule Exibee.Valve do
  @moduledoc """
  Inlet valve management.
  Inlet valves have only two position "open" and "closed".
  # status
    - state indicates the state of the process
    -- :init means initializing
    -- :open means the valve is open.
    -- :closed means the valve is closed.
    -- :to_open (:to_close v.v.) means the process accepted open (close) call and detect the open (closed) limit switch yet.
    - timeout indicates about the last operation
    -- :ok means the last operation was finished in the designated time.
    -- :error means the last operation violated the time
  """

  use GenServer
  alias Exibee.Elib, as: E

  @common Application.get_env(:exibee, :common)
  @default_valve :inlet_valve_control
  @default_open_sw :inlet_valve_open
  @default_closed_sw :inlet_valve_closed
  @timeout_in_ms 10_000

  @doc """
  Start a valve process.

  ## argument
    - v_name: valve name that must be a DO bit name to be open and close. This name is also used as the name of the process to be accessed later.
    - open_limit: name of the limit switch to detect completely open. the name must be a DI bit of the switch.
    - close_limit: similar to open_limit but as of the close limit switch.
  ## description
    starts a genserver process. Other functions must be called with v_name.
  ## example
      iex> start_link({:inlet_valve_control, :inlet_valve_open, :inlet_valve_closed})
  """
  def start_link(
        {v_name, open_limit, close_limit} \\ {@default_valve, @default_open_sw,
         @default_closed_sw}
      ) do
    E.send_log(__MODULE__, __ENV__, "start_link: #{inspect(v_name)}", :notice)
    state = :init
    # should be :init, :open, :closed, :to_open, and :to_close
    timeout = :ok
    # should be :ok, :error
    genserver_status = {state, timeout, open_limit, close_limit}
    GenServer.start_link(__MODULE__, genserver_status, name: v_name)
  end

  @doc """
  get the current state of the valve
  # argument
    - v_name: name of the valve
  # example
    - get_state(:inlet_valve_control)
  """
  def get_state(v_name \\ @default_valve) do
    GenServer.call(v_name, :get_state)
  end

  @doc """
  Let the valve open.
  This function only starts the actuator.
  ## argument
    - v_name: valve name that you indicate as v_name at start_link function.
  ## return value
    - :ok
    - :error
  ## example
      iex> open(:inlet_valve_control)
  """
  def open(v_name \\ @default_valve) do
    GenServer.call(v_name, {:open, v_name})
  end

  @doc """
  Let the valve to be closed.
  This function only starts the actuator to close the valve.
  ## argument
    - v_name: valve name that you indicate as v_name at start_link function.
  ## return value
    - :ok
    - :error
  ## example
      iex> close(:inlet_valve_control)
  """
  def close(v_name \\ @default_valve) do
    GenServer.call(v_name, {:close, v_name})
  end

  @doc """
  reset time out situation
  # argument
    - v_name: name of the valve
  ## return value
    - :ok
    - :error
  # example
    - reset_error(:inlet_valve_control)
  """
  def reset_error(v_name \\ @default_valve) do
    GenServer.call(v_name, :reset_error)
  end

  @impl GenServer
  def init(status) do
    E.send_log(__MODULE__, __ENV__, "init: state: #{show(status)}", :notice)
    {_, _, open_limit, close_limit} = status
    new_status = {:closed, :ok, open_limit, close_limit}
    E.send_log(__MODULE__, __ENV__, "init: new_state #{show(new_status)}", :notice)
    {:ok, new_status}
  end

  @impl GenServer
  def handle_call({:open, valve}, _from, status = {:closed, :ok, ol, cl}) do
    E.send_log(__MODULE__, __ENV__, "open: ok, #{show(status)}", :notice)
    E.set_do(valve, 0)

    Process.send_after(self(), :timer, @timeout_in_ms)
    {:reply, :ok, {:to_open, :ok, ol, cl}}
  end

  @impl GenServer
  def handle_call({:open, _valve}, _from, status) do
    E.send_log(__MODULE__, __ENV__, "open: not closed yet, #{show(status)}", :warn)
    {:reply, :error, status}
  end

  @impl GenServer
  def handle_call({:close, valve}, _from, status) do
    E.send_log(__MODULE__, __ENV__, "close: #{show(status)}", :notice)

    E.set_do(valve, 1)
    Process.send_after(self(), :timer, @timeout_in_ms)

    case status do
      {:open, x, y, z} -> {:reply, :ok, {:to_close, x, y, z}}
      {_, x, y, z} -> {:reply, :error, {:to_close, x, y, z}}
    end
  end

  @impl GenServer
  def handle_call(:get_state, _from, status) do
    E.send_log(__MODULE__, __ENV__, "get_state: status: #{show(status)}", :notice)
    {:reply, status, status}
  end

  @impl GenServer
  def handle_call(:reset_error, _from, status) do
    {state, timeout, open_limit, close_limit} = status
    E.send_log(__MODULE__, __ENV__, "reset_error: status: #{show(status)}", :notice)

    {ret, new_state, new_timeout} = check_reset_condition(state, timeout, close_limit)
    new_status = {new_state, new_timeout, open_limit, close_limit}
    E.send_log(__MODULE__, __ENV__, "reset_error: new_status: #{show(new_status)}", :notice)
    {:reply, ret, new_status}
  end

  @impl GenServer
  def handle_info(:timer, status) do
    E.send_log(__MODULE__, __ENV__, "timer: status: #{show(status)}", :notice)
    {state, timeout, open_limit, close_limit} = status

    cur =
      case {state, E.get_di(open_limit), E.get_di(close_limit)} do
        {_, 0, 0} ->
          [:limit_switch_error, :error]

        {:to_open, 0, _} ->
          [:open, timeout]

        {:open, 0, _} ->
          E.send_log(__MODULE__, __ENV__, "timer: already open", :warn)
          [:open, timeout]

        {:to_close, _, 0} ->
          [:closed, timeout]

        {:closed, _, 0} ->
          E.send_log(__MODULE__, __ENV__, "timer: already closed", :warn)
          [:closed, timeout]

        _ ->
          [state, :error]
      end

    # if time out state changed :ok to :error then cause malfunction
    if timeout == :ok && Enum.at(cur, 1) == :error do
      E.send_log(__MODULE__, __ENV__, "timer: open/close timed out!", :error)
      GenServer.cast(@common[:health_check_server], {:update_malfunction, true})
    end

    # if both switches are on then cause malfunction
    if Enum.at(cur, 1) == :limit_switch_error do
      E.send_log(__MODULE__, __ENV__, "timer: both limit switches are on", :error)
      GenServer.cast(@common[:health_check_server], {:update_malfunction, true})
    end

    new_status = (cur ++ [open_limit] ++ [close_limit]) |> List.to_tuple()
    E.send_log(__MODULE__, __ENV__, "timer: new_status: #{show(new_status)}", :notice)
    {:noreply, new_status}
  end

  defp check_reset_condition(cur_state, cur_timeout, close_limit) do
    case E.get_di(close_limit) do
      0 ->
        {:ok, :closed, :ok}

      _ ->
        E.send_log(
          __MODULE__,
          __ENV__,
          "reset_error: incomplete: inlet valve is not closed, cannot reset",
          :error
        )

        {:error, cur_state, cur_timeout}
    end
  end

  #  defp show({state, timeout, _, _}), do: inspect(state) <> ", " <> inspect(timeout)
  defp show(x), do: inspect(x)
end
