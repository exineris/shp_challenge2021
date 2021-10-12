defmodule Exibee.HealthCheck.HealthCheckServer do
  use GenServer
  require Logger

  alias Exibee.Elib, as: E

  @common Application.get_env(:exibee, :common)

  @logic_controller_server @common[:logic_controller_server]
  @initial_malfunction_state false

  #
  # Client API
  #
  def start_link([pname, malfunction]) do
    case [E.conn_nodes_ping?()] do
      [true] ->
        Process.sleep(1_000)
        E.send_log(__MODULE__, __ENV__, "start")
        GenServer.start_link(__MODULE__, malfunction, name: pname)

      [_] ->
        __MODULE__.start_link([pname, malfunction])
    end
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  #
  # GenServer Callback
  #
  # 正常か異常を返す
  #   - 正常：malfunction = false
  #   - 異常：malfunction = true
  def handle_call(:get_malfunction, _from, malfunction) do
    {:reply, malfunction, malfunction}
  end

  def handle_call({:get_running_condition, new_state}, _from, malfunction) do
    {:reply, get_running_condition(new_state), malfunction}
  end

  # StateServerから状態を受け取り、処理をする
  #   - malfunction = false （正常系処理）
  #   - malfunction = true （異常系処理）
  def handle_cast({:update_state, [_state, new_state]}, false) do
    E.send_log(__MODULE__, __ENV__, ":update_state(false)")

    malfunction =
      case running_condition?(new_state) do
        :good_condition ->
          false

        :warn_condition ->
          send_log_warn(new_state, __ENV__)
          false

        :bad_condition ->
          GenServer.cast(@logic_controller_server, {:malfunction, true})
          true
      end

    {:noreply, malfunction}
  end

  def handle_cast({:update_state, [state, new_state]}, true) do
    E.send_log(__MODULE__, __ENV__, ":update_state(true)")

    condition = [
      running_condition?(new_state),
      E.check_button_down(state, new_state, :emergency_button_down)
    ]

    malfunction =
      case condition do
        [:good_condition, {:falling, [_state, _new_state]}] ->
          # 1→0 b接点 非常停止ボタンが解除された
          false

        [:good_condition, _] ->
          true

        [:warn_condition, _] ->
          send_log_warn(new_state, __ENV__)
          true

        [:bad_condition, _] ->
          true
      end

    {:noreply, malfunction}
  end

  # 外部からmalfunctionを受け取り状態を更新する
  def handle_cast({:update_malfunction, new_malfunction}, malfunction) do
    E.send_log(__MODULE__, __ENV__, ":update_malfunction #{malfunction} -> #{new_malfunction}")

    case [malfunction, new_malfunction] do
      [false, true] ->
        GenServer.cast(@logic_controller_server, {:malfunction, true})
        {:noreply, new_malfunction}

      [_, _] ->
        {:noreply, new_malfunction}
    end
  end

  # GenServer起動時の処理
  def init(_malfunction) do
    E.send_log(__MODULE__, __ENV__, "start")
    malfunction = @initial_malfunction_state
    {:ok, malfunction}
  end

  # GenServer終了時の処理
  def terminate(reason, _) do
    reason
  end

  #
  # function
  #
  def send_log_warn(state, env) do
    generator_temperature_casing = E.get_ai(state, :generator_temperature_casing)
    head_tank_water_level = E.get_ai(state, :head_tank_water_level)

    warn_list = [
      generator_temperature_casing |> check_temp(),
      head_tank_water_level |> check_water_level()
    ]

    case warn_list do
      [{:warn, _}, {:warn, _}] ->
        E.send_log(
          __MODULE__,
          env,
          "generator_temperature_casing: Warning (#{inspect(generator_temperature_casing)})"
        )

        E.send_log(
          __MODULE__,
          env,
          "head_tank_water_level: Warning (#{inspect(head_tank_water_level)})"
        )

      [{:warn, _}, _] ->
        E.send_log(
          __MODULE__,
          env,
          "generator_temperature_casing: Warning (#{inspect(generator_temperature_casing)})"
        )

      [_, {:warn, _}] ->
        E.send_log(
          __MODULE__,
          env,
          "head_tank_water_level: Warning (#{inspect(head_tank_water_level)})"
        )

      [_, _] ->
        :noop
    end
  end

  def check_temp(temp) do
    case temp do
      temp when 90 <= temp -> {:error, temp}
      temp when 80 <= temp and temp < 90 -> {:warn, temp}
      temp when 4 <= temp and temp < 80 -> {:good, temp}
      temp when 0 <= temp and temp < 4 -> {:error, temp}
      _temp -> {:error, temp}
    end
  end

  def check_water_level(water_level) do
    case water_level do
      water_level when 1000 <= water_level -> {:good, water_level}
      water_level when 4 <= water_level and water_level < 1000 -> {:warn, water_level}
      water_level when 0 <= water_level and water_level < 4 -> {:error, water_level}
      _water_level -> {:error, water_level}
    end
  end

  def get_running_condition(new_state) do
    check_list = [
      E.get_di(new_state, :grid_mulfunction_detected),
      E.get_di(new_state, :driver_inverter_error),
      E.get_di(new_state, :power_main_trip),
      E.get_di(new_state, :power_main_out),
      E.get_di(new_state, :elcb_trip),
      E.get_di(new_state, :elcb_out),
      E.get_di(new_state, :over_voltage_trip),
      E.get_di(new_state, :over_voltage_out),
      E.get_di(new_state, :lighting_main_trip),
      E.get_di(new_state, :lighting_main_out),
      E.get_di(new_state, :generator_over_speed),
      E.get_di(new_state, :inlet_valve_over_torque),
      E.get_di(new_state, :dummy_load_trouble),
      E.get_ai(new_state, :generator_temperature_casing) |> check_temp(),
      E.get_ai(new_state, :head_tank_water_level) |> check_water_level()
    ]

    E.send_log(__MODULE__, __ENV__, "#{inspect(check_list)}")

    check_list
  end

  def running_condition?(new_state) do
    case get_running_condition(new_state) do
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, {:good, _}, {:good, _}] -> :good_condition
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, {:good, _}, {:warn, _}] -> :warn_condition
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, {:warn, _}, {:good, _}] -> :warn_condition
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, {:warn, _}, {:warn, _}] -> :warn_condition
      [_, _, _, _, _, _, _, _, _, _, _, _, _, _, _] -> :bad_condition
    end
  end
end
