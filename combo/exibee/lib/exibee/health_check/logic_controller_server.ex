defmodule Exibee.HealthCheck.LogicControllerServer do
  use GenServer
  require Logger

  alias Exibee.Elib, as: E
  alias Exibee.LogicController, as: LC

  @common Application.get_env(:exibee, :common)

  @health_check_server @common[:health_check_server]

  #
  # Client API
  #
  def start_link([pname, lc_state]) do
    case [E.conn_nodes_ping?()] do
      [true] ->
        Process.sleep(1_000)
        E.send_log(__MODULE__, __ENV__, "start")
        GenServer.start_link(__MODULE__, lc_state, name: pname)

      [_] ->
        __MODULE__.start_link([pname, lc_state])
    end
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  #
  # GenServer Callback
  #
  # StateServerから状態を受け取りLogicControllerの処理をする
  def handle_cast({:update_state, [state, new_state]}, lc_state) do
    E.send_log(__MODULE__, __ENV__, ":update_state")

    operation_list = [
      GenServer.call(@health_check_server, :get_malfunction),
      E.check_button_down(state, new_state, :emergency_button_down),
      E.check_button_down(state, new_state, :stop_button_down),
      E.check_button_down(state, new_state, :start_button_down)
    ]

    case operation_list do
      [_, {:rising, [_state, _new_state]}, _, _] ->
        # 0→1 b接点 非常停止ボタンが押された
        GenServer.cast(@health_check_server, {:update_malfunction, true})
        LC.emergency_button_down()

      [false, {:falling, [_state, _new_state]}, _, _] ->
        # 1→0 b接点 非常停止ボタンが解除された
        LC.emergency_button_up()

      [false, _, {:falling, [_state, _new_state]}, _] ->
        LC.stop_button_down()

      [false, _, _, {:falling, [_state, _new_state]}] ->
        LC.start_button_down()

      [_, _, _, _] ->
        E.send_log(__MODULE__, __ENV__, "noop")
        :noop
    end

    {:noreply, lc_state}
  end

  # HealthCheckServerから異常フラグを受け取りLogicControllerの処理をする
  def handle_cast({:malfunction, malfunction}, lc_state) do
    E.send_log(__MODULE__, __ENV__, ":malfunction")

    case malfunction do
      true -> LC.mulfunction()
      false -> :noop
      _ -> :noop
    end

    {:noreply, lc_state}
  end

  # GenServer起動時の処理
  def init(lc_state) do
    E.send_log(__MODULE__, __ENV__, "start")
    {:ok, lc_state}
  end

  # GenServer終了時の処理
  def terminate(reason, _) do
    reason
  end
end
