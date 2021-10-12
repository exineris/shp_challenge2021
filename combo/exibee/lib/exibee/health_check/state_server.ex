defmodule Exibee.HealthCheck.StateServer do
  use GenServer
  require Logger

  alias Exibee.Elib, as: E

  @common Application.get_env(:exibee, :common)

  @health_check_server @common[:health_check_server]
  @logic_controller_server @common[:logic_controller_server]
  @gpio_interrupt_di @common[:gpio_interrupt_di]
  @gpio_falling @common[:gpio_falling]

  @update_state_timer 60_000

  #
  # Client API
  #
  def start_link([pname, state]) do
    case [E.conn_nodes_ping?()] do
      [true] ->
        Process.sleep(1_000)
        E.send_log(__MODULE__, __ENV__, "start")
        GenServer.start_link(__MODULE__, state, name: pname)

      [_] ->
        __MODULE__.start_link([pname, state])
    end
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  #
  # GenServer Callback
  #
  # exidioのDIの状態を受け取って状態を更新する
  def handle_cast({:exidio_dis, _dis}, [_state, new_state]) do
    E.send_log(__MODULE__, __ENV__, ":exidio_dis")

    state = new_state
    new_state = E.get_all_device_status()
    states_cast([state, new_state])

    {:noreply, [state, new_state]}
  end

  # 現在の状態を返す
  def handle_call(:get_state, _from, [state, new_state]) do
    {:reply, [state, new_state], [state, new_state]}
  end

  # exicomobo自身のDIのインタラプトに反応して状態を更新する
  def handle_info(
        {:circuits_gpio, @gpio_interrupt_di, _time, @gpio_falling},
        [_state, new_state]
      ) do
    E.send_log(__MODULE__, __ENV__, ":circuits_gpio")

    state = new_state
    new_state = E.get_all_device_status()
    states_cast([state, new_state])

    {:noreply, [state, new_state]}
  end

  # タイマーで起動して状態を更新する
  def handle_info(:update_state_timer, [_state, new_state]) do
    E.send_log(__MODULE__, __ENV__, ":update_state_timer")

    state = new_state
    new_state = E.get_all_device_status()
    states_cast([state, new_state])

    Process.send_after(self(), :update_state_timer, @update_state_timer)

    {:noreply, [state, new_state]}
  end

  # /dev/null
  def handle_info(_msg, [state, new_state]) do
    # Logger.warn("#{__MODULE__} get_message_except: #{inspect(msg)} #{inspect(state)}")
    {:noreply, [state, new_state]}
  end

  # GenServer起動時の処理
  def init(_state) do
    E.send_log(__MODULE__, __ENV__, "start")

    state = E.get_all_device_status()
    new_state = state

    Exi.GPIO.start_link(:di, @gpio_interrupt_di, :input, self())

    send(self(), :update_state_timer)

    {:ok, [state, new_state]}
  end

  # GenServer終了時の処理
  def terminate(reason, _) do
    reason
  end

  #
  # private function
  #
  defp states_cast([state, new_state]) do
    GenServer.cast(@health_check_server, {:update_state, [state, new_state]})
    GenServer.cast(@logic_controller_server, {:update_state, [state, new_state]})
  end
end
