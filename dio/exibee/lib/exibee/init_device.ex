defmodule Exibee.InitDevice do
  alias Exibee.Elib, as: E

  @common Application.get_env(:exibee, :common)

  def start() do
    E.send_log(__MODULE__, __ENV__, "Exibee: Init I2C configration")

    {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])

    # 入力ピン設定（DI）
    # Circuits.I2C.write(ref, @common[:device_di], <<@common[:iodir_a], @common[:iodir_a_default]>>)

    # 入力ピン割り込み設定（DI）
    Circuits.I2C.write(
      ref,
      @common[:device_di],
      <<@common[:gpinten_a], @common[:gpinten_a_enable]>>
    )

    Circuits.I2C.write(
      ref,
      @common[:device_di],
      <<@common[:gpinten_b], @common[:gpinten_b_enable]>>
    )

    Circuits.I2C.write(ref, @common[:device_di], <<@common[:intcon_a], @common[:intcon_a_set]>>)
    Circuits.I2C.write(ref, @common[:device_di], <<@common[:intcon_b], @common[:intcon_b_set]>>)

    # 出力ピン設定（DO）
    Circuits.I2C.write(ref, @common[:device_do], <<@common[:olat_a], @common[:olat_a_default]>>)
    Circuits.I2C.write(ref, @common[:device_do], <<@common[:olat_b], @common[:olat_b_default]>>)

    Circuits.I2C.write(ref, @common[:device_do], <<@common[:iodir_a], @common[:iodir_a_default]>>)
    Circuits.I2C.write(ref, @common[:device_do], <<@common[:iodir_b], @common[:iodir_b_default]>>)

    # LED初期化
    File.write(@common[:led_green] <> "trigger", "none")
    File.write(@common[:led_orange] <> "trigger", "none")
    File.write(@common[:led_yellow] <> "trigger", "none")
    File.write(@common[:led_red] <> "trigger", "none")

    :ok
  end
end
