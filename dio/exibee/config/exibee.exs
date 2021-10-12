import Config

# ==============================
# Exibee Configration
# ==============================
config :exibee,
  common: %{
    exicombo: {:global, :exicombo},
    state_server: {:global, :state_server},
    health_check_server: {:global, :health_check_server},
    logic_controller_server: {:global, :logic_controller_server},
    exidio: {:global, :exidio},
    i2c_bus: "i2c-1",
    device_di: 0x20,
    device_do: 0x21,
    iodir_a: 0x00,
    iodir_b: 0x01,
    iodir_a_default: 0x00,
    iodir_b_default: 0x00,
    gpinten_a: 0x04,
    gpinten_b: 0x05,
    gpinten_a_enable: 0xFF,
    gpinten_b_enable: 0xFF,
    intcon_a: 0x08,
    intcon_a_set: 0x00,
    intcon_b: 0x09,
    intcon_b_set: 0x00,
    gpio_a: 0x12,
    gpio_b: 0x13,
    olat_a: 0x14,
    olat_b: 0x15,
    olat_a_default: 0xFF,
    olat_b_default: 0xFF,
    read_byte_di: 1,
    read_byte_do: 1,
    digit_2: 2,
    digit_4: 4,
    digit_8: 8,
    digit_16: 16,
    padding_0: "0",
    led_green: "/sys/class/leds/beaglebone:green:usr0/",
    led_orange: "/sys/class/leds/beaglebone:green:usr2/",
    led_yellow: "/sys/class/leds/beaglebone:green:usr1/",
    led_red: "/sys/class/leds/beaglebone:green:usr3/",
    led_on: "1",
    led_off: "0",
    led_timer: "timer",
    gpio_interrupt_di_1: 48,
    gpio_interrupt_di_2: 49,
    gpio_falling: 0,
    gpio_rising: 1
  }

config :exibee,
  din_exicombo: %{
    start_button_down: 0,
    stop_button_down: 1,
    emergency_button_down: 2,
    grid_mulfunction_detected: 3,
    inverter_ready: 4,
    driver_inverter_error: 5,
    driver_inverter_running: 6,
    reserve7: 7
  }

config :exibee,
  din_exidio: %{
    parallel_off_relay_activated: 0,
    power_main_trip: 1,
    power_main_out: 2,
    elcb_trip: 3,
    elcb_out: 4,
    over_voltage_trip: 5,
    over_voltage_out: 6,
    lighting_main_trip: 7,
    lighting_main_out: 8,
    generator_over_speed: 9,
    inlet_valve_over_torque: 10,
    inlet_valve_closed: 11,
    inlet_valve_open: 12,
    dummy_load_trouble: 13,
    reserve14: 14,
    reserve15: 15
  }

config :exibee,
  dout_exicombo: %{
    exicombo_do_0: 0,
    exicombo_do_1: 1,
    exicombo_do_2: 2,
    exicombo_do_3: 3,
    exicombo_initialize: 0b1110,
    exicombo_cluster_mulfunction: 0b1111,
    exicombo_inverter_operation_order: 0b1100,
    exicombo_inverter_error_reset: 0b1010
  }

config :exibee,
  dout_exidio: %{
    cluster_mulfunction: 0,
    inlet_valve_control: 1,
    parallel_off_relay_deactivated: 2,
    parallel_off_relay_activated: 3,
    exidio_do_0: 0,
    exidio_do_1: 1,
    exidio_do_2: 2,
    exidio_do_3: 3,
    exidio_do_4: 4,
    exidio_do_5: 5,
    exidio_do_6: 6,
    exidio_do_7: 7,
    exidio_do_8: 8,
    exidio_do_9: 9,
    exidio_do_10: 10,
    exidio_do_11: 11,
    exidio_do_12: 12,
    exidio_do_13: 13,
    exidio_do_14: 14,
    exidio_do_15: 15,
    exidio_initialize: [0b11111111, 0b11111110],
    exidio_cluster_mulfunction: [0b11111111, 0b11111111],
    exidio_parallel_off_relay_deactivated: [0b11111111, 0b11111010],
    exidio_parallel_off_relay_activated: [0b11111111, 0b11110110]
  }
