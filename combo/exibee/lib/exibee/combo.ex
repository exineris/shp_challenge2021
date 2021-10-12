defmodule Exibee.Combo do
  alias Exibee.Elib, as: E

  @common Application.get_env(:exibee, :common)
  @dout Application.get_env(:exibee, :dout)

  def get_all_dis do
    {function_name, _} = __ENV__.function
    {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])

    # 入出力ピン設定
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:iodir_a], @common[:iodir_a_default]>>)

    # すべてのDIの値を読み出し
    log =
      Circuits.I2C.write_read!(
        ref,
        @common[:device_1],
        <<@common[:gpio_a]>>,
        @common[:read_byte_di]
      )
      |> E.to_binary_decode_unsigned()
      |> E.format0b(@common[:digit_8])

    E.send_log(__MODULE__, function_name, log)
  end

  def blink_all_dos do
    {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])

    # 入出力ピン設定
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:olat_b], @common[:olat_b_default]>>)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:iodir_b], @common[:iodir_b_default]>>)

    # DOチカチカ
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:all_on]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:all_off]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:all_on]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:all_off]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:all_on]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:all_off]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do0_on]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do1_on]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do2_on]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do3_on]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do2_on]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do1_on]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do0_on]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:all_on]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do0_off]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do1_off]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do2_off]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do3_off]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do2_off]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do1_off]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:do0_off]>>)
    Process.sleep(500)
    Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout[:all_on]>>)
  end

  def get_all_ais do
    {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])

    # ADC初期化
    Circuits.I2C.write(
      ref,
      @common[:adc],
      <<@common[:adc_addr_high], @common[:adc_addr_low], @common[:adc_init]>>
    )

    Process.sleep(500)

    Circuits.I2C.write(
      ref,
      @common[:adc],
      <<@common[:adc_addr_high], @common[:adc_addr_low], @common[:adc_read_command]>>
    )

    # AI読み込み
    # {:ok, <<ai0::(32), ai1::(32), ai2::(32), ai3::(32), ai4::(32), ai5::(32)>>} = Circuits.I2C.write_read(ref, @common[:adc], <<@common[:adc_reg_addr_high], @common[:adc_reg_addr_low]>>, @common[:read_byte_ai])
    {:ok,
     <<
       ai0_h::12,
       _ai0_l::12,
       _ai0_status::5,
       _ai0_channel::3,
       ai1_h::12,
       _ai1_l::12,
       _ai1_status::5,
       _ai1_channel::3,
       ai2_h::12,
       _ai2_l::12,
       _ai2_status::5,
       _ai2_channel::3,
       ai3_h::12,
       _ai3_l::12,
       _ai3_status::5,
       _ai3_channel::3,
       ai4_h::12,
       _ai4_l::12,
       _ai4_status::5,
       _ai4_channel::3,
       ai5_h::12,
       _ai5_l::12,
       _ai5_status::5,
       _ai5_channel::3
     >>} =
      Circuits.I2C.write_read(
        ref,
        @common[:adc],
        <<@common[:adc_reg_addr_high], @common[:adc_reg_addr_low]>>,
        @common[:read_byte_ai]
      )

    %{ai0: ai0_h, ai1: ai1_h, ai2: ai2_h, ai3: ai3_h, ai4: ai4_h, ai5: ai5_h}
  end

  def write_ao do
    {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])

    # 10mA電流出力初期化（表示：0.00）
    Circuits.I2C.write(
      ref,
      @common[:dac],
      <<@common[:dac_channel], @common[:dac_out_000_high], @common[:dac_out_000_low]>>
    )

    Process.sleep(1000)

    # 10mA電流出力（表示：1.00）
    Circuits.I2C.write(
      ref,
      @common[:dac],
      <<@common[:dac_channel], @common[:dac_out_100_high], @common[:dac_out_100_low]>>
    )
  end

  def get_all_status do
    [Exibee.Combo.get_all_dis(), Exibee.Combo.get_all_ais()]
  end
end
