defmodule Exibee.InitDevice do
  alias Exibee.Elib, as: E

  @common Application.get_env(:exibee, :common)

  def start() do
    E.send_log(__MODULE__, __ENV__, "Exibee: Init I2C configration")

    {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])

    # 入力ピン設定（DI）
    # Circuits.I2C.write(ref, @common[:device_1], <<@common[:iodir_a], @common[:iodir_a_default]>>)

    # 入力ピン割り込み設定（DI）
    Circuits.I2C.write(
      ref,
      @common[:device_1],
      <<@common[:gpinten_a], @common[:gpinten_a_enable]>>
    )

    Circuits.I2C.write(ref, @common[:device_1], <<@common[:intcon_a], @common[:intcon_a_set]>>)

    # 出力ピン設定（DO）
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:olat_b], @common[:olat_b_default]>>)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:iodir_b], @common[:iodir_b_default]>>)

    # ADC初期化（AI）
    Circuits.I2C.write(
      ref,
      @common[:adc],
      <<@common[:adc_addr_high], @common[:adc_addr_low], @common[:adc_init]>>
    )

    Process.sleep(500)

    # 電流出力初期化（AO）
    Circuits.I2C.write(
      ref,
      @common[:dac],
      <<@common[:dac_channel], @common[:dac_out_000_high], @common[:dac_out_000_low]>>
    )

    Process.sleep(1000)

    # LED初期化
    File.write(@common[:led_green] <> "trigger", "none")
    File.write(@common[:led_orange] <> "trigger", "none")
    File.write(@common[:led_yellow] <> "trigger", "none")
    File.write(@common[:led_red] <> "trigger", "none")

    :ok
  end
end
