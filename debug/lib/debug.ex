defmodule Debug do
  @moduledoc """
  exi_shp_199のデバッグのために利用するモジュール。

  以下のようなコマンドを実行後利用する。
  ```
  ❯ iex --name my_node@192.168.5.111 --cookie comecomeeverybody -S mix
  iex> Node.connect(:"exicombo@192.168.5.55")
  ```
  """

  require Logger

  @common Application.compile_env(:debug, :common)
  @state_server @common[:state_server]
  @health_check_server @common[:health_check_server]

  def print(sleep_ms \\ 1000) do
    [_state, new_state] = GenServer.call(@state_server, :get_state)
    malfunction = GenServer.call(@health_check_server, :get_malfunction)
    running_condition = GenServer.call(@health_check_server, {:get_running_condition, new_state})

    do_format_print(new_state, malfunction, running_condition)

    Process.sleep(sleep_ms)
  end

  defp do_format_print(state, malfunction, running_condition) do
    [exicombo_ai, exicombo_di, exidio_di] = do_format_split_state(state)

    IO.puts("""
    === exicombo ai ===
      head_tank_water_level        => #{inspect(Enum.at(exicombo_ai, 0))}
      generator_temperature_casing => #{inspect(Enum.at(exicombo_ai, 5))}
    """)

    IO.puts("""
    === exicombo di ===
      reserve7                     => #{inspect(Enum.at(exicombo_di, 0))}
      driver_inverter_running      => #{inspect(Enum.at(exicombo_di, 1))}
      driver_inverter_error        => #{inspect(Enum.at(exicombo_di, 2))} r
      inverter_ready               => #{inspect(Enum.at(exicombo_di, 3))}
      grid_mulfunction_detected    => #{inspect(Enum.at(exicombo_di, 4))} r
      emergency_button_down        => #{inspect(Enum.at(exicombo_di, 5))} *
      stop_button_down             => #{inspect(Enum.at(exicombo_di, 6))}
      start_button_down            => #{inspect(Enum.at(exicombo_di, 7))}
    """)

    IO.puts("""
    === exidio di ===
      reserve15                    => #{inspect(Enum.at(exidio_di, 0))}
      reserve14                    => #{inspect(Enum.at(exidio_di, 1))}
      dummy_load_trouble           => #{inspect(Enum.at(exidio_di, 2))} r
      inlet_valve_open             => #{inspect(Enum.at(exidio_di, 3))}
      inlet_valve_closed           => #{inspect(Enum.at(exidio_di, 4))}
      inlet_valve_over_torque      => #{inspect(Enum.at(exidio_di, 5))} r
      generator_over_speed         => #{inspect(Enum.at(exidio_di, 6))} r
      lighting_main_out            => #{inspect(Enum.at(exidio_di, 7))} r
      lighting_main_trip           => #{inspect(Enum.at(exidio_di, 8))} r
      over_voltage_out             => #{inspect(Enum.at(exidio_di, 9))} r
      over_voltage_trip            => #{inspect(Enum.at(exidio_di, 10))} r
      elcb_out                     => #{inspect(Enum.at(exidio_di, 11))} r
      elcb_trip                    => #{inspect(Enum.at(exidio_di, 12))} r
      power_main_out               => #{inspect(Enum.at(exidio_di, 13))} r
      power_main_trip              => #{inspect(Enum.at(exidio_di, 14))} r
      parallel_off_relay_activated => #{inspect(Enum.at(exidio_di, 15))}
    """)

    IO.puts("""
    === malfunction ===
      #{inspect(malfunction)}
    """)

    IO.puts("""
    === running_condition ===
      #{inspect(running_condition)}
    """)
  end

  defp do_format_split_state(state) do
    exicombo_ai = state[:exicombo].ai
    exicombo_di = state[:exicombo].di
    exidio_di = state[:exidio].di

    [exicombo_ai, exicombo_di, exidio_di]
  end
end
