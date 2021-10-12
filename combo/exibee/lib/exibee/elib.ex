defmodule Exibee.Elib do
  require Logger
  use Bitwise

  alias Exibee.Elib, as: E

  @common Application.get_env(:exibee, :common)
  @ain_exicombo Application.get_env(:exibee, :ain_exicombo)
  @din_exicombo Application.get_env(:exibee, :din_exicombo)
  @din_exidio Application.get_env(:exibee, :din_exidio)
  @dout_exicombo Application.get_env(:exibee, :dout_exicombo)
  @dout_exidio Application.get_env(:exibee, :dout_exidio)

  @exicombo @common[:exicombo]
  @exidio @common[:exidio]
  @state_server @common[:state_server]

  @doc """
  10進整数と桁を入力すると桁数分ゼロ埋めした2進数リストに変換する。

  ## パラメータ
    - value: 10進数の整数
    - digit: 桁（ビット）

  ## 例
      iex> format0b(111, 8)
      [0, 1, 1, 0, 1, 1, 1, 1]
  """
  def format0b(value, digit) do
    value
    |> Integer.to_string(@common[:digit_2])
    |> String.pad_leading(digit, @common[:padding_0])
    |> String.codepoints()
    |> Enum.map(fn n -> String.to_integer(n) end)
  end

  @doc """
  バイナリデータをバイナリデータじゃなくする。

  ## パラメータ
    - binary: バイナリデータ

  ## 例
      iex> to_binary_decode_unsigned(<<111>>)
      111
  """
  def to_binary_decode_unsigned(binary) do
    :binary.decode_unsigned(binary)
  end

  @doc """
  すべてのLEDを点灯・消灯する。

  ## パラメータ
    - behavior: "0" or "1"

  ## 例
      iex> Exibee.Elib.set_all_led("0")  # => 全LED消灯
      iex> Exibee.Elib.set_all_led("1")  # => 全LED点灯

  """
  def set_all_leds(behavior \\ "") do
    leds = ["green", "orange", "yellow", "red"]
    log = Enum.map(leds, fn led -> E.set_led(led, behavior) end)

    E.send_log(__MODULE__, __ENV__, log)
  end

  @doc """
  LEDを点灯・消灯する。

  ## パラメータ
    - color: "green", "orange", "yellow", "red"
    - behavior: "0" / "1" / "timer"
    - delay_on: 点灯時間（ミリ秒）
    - delay_off: 消灯時間（ミリ秒）

  ## 例
      iex> Exibee.Elib.set_led("yellow", "0")  # => 黄色LED消灯
      iex> Exibee.Elib.set_led("yellow", "1")  # => 黄色LED点灯
      iex> Exibee.Elib.set_led("green", "timer", "200", "800")  # => 緑色LEDが200ミリ秒点灯して800ミリ秒消灯
  """
  def set_led(color \\ "", behavior \\ "", delay_on \\ "1000", delay_off \\ "1000") do
    led =
      case color do
        "green" -> @common[:led_green]
        "orange" -> @common[:led_orange]
        "yellow" -> @common[:led_yellow]
        "red" -> @common[:led_red]
        _ -> "color error."
      end

    log =
      case [behavior, delay_on, delay_off] do
        ["timer", delay_on, delay_off] ->
          File.write(led <> "trigger", @common[:led_timer])
          File.write(led <> "delay_on", delay_on)
          File.write(led <> "delay_off", delay_off)

        ["1", _, _] ->
          File.write(led <> "brightness", @common[:led_on])

        ["0", _, _] ->
          File.write(led <> "brightness", @common[:led_off])

        [_, _, _] ->
          "behavior error."
      end

    log = inspect(log) <> " " <> color
    E.send_log(__MODULE__, __ENV__, log)
  end

  @doc """
  LEDを流れるように表示する。

  ## パラメータ
    - flow: ':green_to_red' or ':red_to_green'

  ## 例
      iex> led_wave(:red_to_green)    # => 赤から緑に流れる表示
  """
  def led_wave(flow \\ :green_to_red) do
    leds = ["green", "orange", "yellow", "red"]

    Exibee.Elib.set_all_leds(@common[:led_off])
    Process.sleep(200)

    case flow do
      :green_to_red ->
        leds
        |> Enum.map(fn led ->
          Exibee.Elib.set_led(led, "timer", "200", "800")
          Process.sleep(200)
        end)

      :red_to_green ->
        Enum.reverse(leds)
        |> Enum.map(fn led ->
          Exibee.Elib.set_led(led, "timer", "200", "800")
          Process.sleep(200)
        end)

      _ ->
        :error
    end
  end

  @doc """
  src_diとdst_diのDIの比較リストを作成する。
  """
  def check_di_all(src_di, dst_di) when length(src_di) == length(dst_di) do
    Enum.map(
      0..(length(src_di) - 1),
      fn bit ->
        [Enum.at(src_di, bit), Enum.at(dst_di, bit)]
      end
    )
  end

  def check_di_all(src_di, dst_di) when length(src_di) != length(dst_di) do
    :check_di_all_error
  end

  @doc """
  2つのstateから指定ビットを取得しリストで返す。

  ## パラメータ
    - state: 現在のstate（get_all_device_status/0と同じ構造）
    - new_state: 新しいstate
    - di_name: @din_(exicombo|exidio)で宣言されているキー

  ## 例
      iex> check_di_state(state, new_state, :emergency_button_down)
      [0, 1]
  """
  def check_di_state(state, new_state, di_name) do
    case get_device_name_di(di_name) do
      @exicombo ->
        {_, name} = @exicombo
        check_di(state[name].di, new_state[name].di, @din_exicombo[di_name])

      @exidio ->
        {_, name} = @exidio
        check_di(state[name].di, new_state[name].di, @din_exidio[di_name])

      _ ->
        :error
    end
  end

  @doc """
  `di_name` から登録されているデバイスを返す。

  ## パラメータ
    - di_name: @din_(exicombo|exidio)で宣言されているキー

  ## 例
      iex> get_device_name_di(:emergency_button_down)
      {:global, :exicombo}    # => @exicombo
  """
  def get_device_name_di(di_name) do
    case [@din_exicombo, @din_exidio]
         |> Enum.map(fn din_map -> Map.has_key?(din_map, di_name) end) do
      [true, false] -> @exicombo
      [false, true] -> @exidio
      [_, _] -> :error
    end
  end

  @doc """
  `do_name` から登録されているデバイスを返す。

  ## パラメータ
    - do_name: @din_(exicombo|exidio)で宣言されているキー

  ## 例
      iex> get_device_name_do(:inlet_valve_control)
      {:global, :exidio}    # => @exidio
  """
  def get_device_name_do(do_name) do
    case [@dout_exicombo, @dout_exidio]
         |> Enum.map(fn dout_map -> Map.has_key?(dout_map, do_name) end) do
      [true, false] -> @exicombo
      [false, true] -> @exidio
      [_, _] -> :error
    end
  end

  @doc """
  2つのDIリストから指定ビットを取得しリストで返す。

  ## パラメータ
    - src_di: 変更前DIリスト（8ビット）
    - dst_di: 変更後DIリスト（8ビット）
    - pin: DIのピン番号（Combo: 0〜7、DIO: 0〜15）

  ## 例
      iex> bdi = [0, 0, 0, 0, 1, 1, 1, 1]
      iex> adi = [0, 0, 0, 0, 0, 1, 1, 1]
      iex> check_di(bdi, adi, 3)
      [1, 0]
  """
  def check_di(src_di, dst_di, pin) when length(src_di) == length(dst_di) do
    enum_index = get_enum_index(src_di, pin)
    [Enum.at(src_di, enum_index), Enum.at(dst_di, enum_index)]
  end

  def check_di(src_di, dst_di, _pin) when length(src_di) != length(dst_di) do
    :check_di_error
  end

  def get_enum_index(src_di, pin) do
    length(src_di) - 1 - pin
  end

  @doc """
  DIのリストからどのような変化をしているか返す。

  ## パラメータ
    - check_di_list: `check_di/3` を実行した結果

  ## 例
      iex> src_di = [0, 0, 0, 0, 1, 1, 1, 1]
      iex> dst_di = [0, 0, 0, 0, 0, 1, 1, 1]
      iex> check_di(src_di, dst_di, 3) |> check_di_change()
      {:falling, [1, 0]}
  """
  def check_di_change(check_di_list) do
    case check_di_list do
      [0, 0] -> {:none, check_di_list}
      [1, 0] -> {:falling, check_di_list}
      [0, 1] -> {:rising, check_di_list}
      [1, 1] -> {:none, check_di_list}
      _ -> {:error, check_di_list}
    end
  end

  @doc """
  `check_di_state/3 |> check_di_change/1` を実行する。

  ## パラメータ
    - state: 現在の状態
    - new_state: 新しい状態
    - button_name_di: DIの名前

  ## 例
      iex> check_button_down(state, new_state, :emergency_button_down)
      {:falling, [1, 0]}
  """
  def check_button_down(state, new_state, button_name_di) do
    E.check_di_state(state, new_state, button_name_di)
    |> E.check_di_change()
  end

  @doc """
  DIの状態をリストで返す。右端がDI0となる。

  ## 例
      iex> get_all_dis()
      [0, 0, 0, 0, 1, 1, 1, 1]
  """
  def get_all_dis(target \\ :local) do
    {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])

    case target do
      :local ->
        # すべてのDIの値を読み出し
        Circuits.I2C.write_read!(
          ref,
          @common[:device_1],
          <<@common[:gpio_a]>>,
          @common[:read_byte_di]
        )
        |> E.to_binary_decode_unsigned()
        |> E.format0b(@common[:digit_8])

      _ ->
        GenServer.call(target, :get_all_dis)
    end
  end

  @doc """
  現在のDIの状態を取得する（0 or 1）。

  ## パラメータ
    - di_name: `config/exibee.ex` で定義されているDIの名前（アトム）

  ## 例
      iex> get_di(:emergency_button_down)
      0
      iex> get_di(:power_main_trip)
      1
  """
  def get_di(di_name) do
    state = get_all_device_status()
    get_di(state, di_name)
  end

  @doc """
  stateにあるDIの状態を取得する（0 or 1）。

  ## パラメータ
    - state: ヘルスチェックで持ちまわっている状態
    - di_name: `config/exibee.ex` で定義されているDIの名前（アトム）

  ## 例
      iex> get_di(state, :emergency_button_down)
      0
      iex> get_di(state, :power_main_trip)
      1
  """
  def get_di(state, di_name) do
    case get_device_name_di(di_name) do
      @exicombo ->
        {_, name} = @exicombo
        enum_index = get_enum_index(state[name].di, @din_exicombo[di_name])
        Enum.at(state[name].di, enum_index)

      @exidio ->
        {_, name} = @exidio
        enum_index = get_enum_index(state[name].di, @din_exidio[di_name])
        Enum.at(state[name].di, enum_index)

      _ ->
        :error
    end
  end

  @doc """
  現在のAIの値を取得する。

  ## パラメータ
    - ai_name: `config/exibee.ex` で定義されているAIの名前（アトム）

  ## 例
      iex> get_ai(:head_tank_water_level)
      480
  """
  def get_ai(ai_name) do
    state = get_all_device_status()
    get_ai(state, ai_name)
  end

  @doc """
  stateにあるAIを取得する。

  ## パラメータ
    - state: ヘルスチェックで持ちまわっている状態
    - ai_name: `config/exibee.ex` で定義されているAIの名前（アトム）

  ## 例
      iex> get_ai(state, :head_tank_water_level)
      480
  """
  def get_ai(state, ai_name) do
    {_, name} = @exicombo
    enum_index = get_enum_index(state[name].ai, @ain_exicombo[ai_name])
    Enum.at(state[name].ai, enum_index)
  end

  @doc """
  AIの状態をリストで返す。右端がAI0となる。

  ## 例
      iex> get_all_ais()
      [218, 370, 198, 432, 982, 1726]
  """
  def get_all_ais() do
    {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])

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

    [get_level(ai5_h), ai4_h, ai3_h, ai2_h, ai1_h, get_temp(ai0_h)]
  end

  @doc """
  Translate raw AI data into tank water level
  ## argument
    - level_raw: raw data of MSB 12bit of ADC
  ## calculation
    - 4mA -> 3000mm, 20mA -> 0mm
    - returns in Integer
  ## example
    - get_level(raw_data_from_ADC_with_unsigned_12bit)
  """
  def get_level(level_raw) do
    # E.send_log(__MODULE__, __ENV__, "#{inspect(level_raw)}")
    round((20.0 - u12_to_mA(level_raw)) * (3000.0 / 16.0))
  end

  @doc """
  Translate raw AI data into PT100 temperture
  Assuming a converter for changing PT100 to 4-20mA
  ## argument
    - temp_raw: raw data of MSB 12bit of ADC
  ## calculation
    - -50 degree C -> 4mA, +200 -> 20mA
    - returns in Integer
  ## example
    - get_level(raw_data_from_ADC_with_unsigned_12bit)
  """
  def get_temp(temp_raw) do
    # E.send_log(__MODULE__, __ENV__, "#{inspect(temp_raw)}")
    round((u12_to_mA(temp_raw) - 4.0) * 15.625 - 50.0)
  end

  @doc """
  Translate raw AI data into mA. Assuming unsigned 12bit of ADC
  # argument
    - raw data
  # example
    - u12_to_mA(raw_data_from_ADC_with_unsigned_12bit)
  """
  def u12_to_mA(raw), do: raw * 0.01197

  @doc """
  全機器のDI/AIを出力する。

  ## 例
      iex> get_all_device_status()
      [
        exicombo: %{ai: [218, 371, 199, 479, 762, 1], di: [0, 1, 1, 0, 1, 0, 1, 1]},
        exidio: %{di: [1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]}
      ]
  """
  def get_all_device_status() do
    [
      exicombo: %{di: E.get_all_dis(:local), ai: E.get_all_ais()},
      exidio: %{di: E.get_all_dis(@exidio)}
    ]
  end

  @doc """
  DOを操作する。

  ## パラメータ
    - do_name: 操作したいDOの名前
    - on_off: 0 or 1（0:On、1:Off）

  ## 例
      iex> set_do(:exicombo_do_0, 0)    # => exicomboのDO 0がOn
      :ok
      iex> set_do(:exidio_do_9, 1)    # => exidioのDO 9がOff
      :ok
  """
  def set_do(do_name, on_off) do
    my_list_replace_at = fn list, do_num, on_off ->
      List.replace_at(list, get_enum_index(list, do_num), on_off)
    end

    case get_device_name_do(do_name) do
      @exicombo ->
        {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])

        command =
          get_current_dos(@exicombo)
          |> format0b(@common[:digit_4])
          |> my_list_replace_at.(@dout_exicombo[do_name], on_off)
          |> Enum.join()
          |> String.to_integer(@common[:digit_2])

        Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], command>>)

      @exidio ->
        list_command =
          get_current_dos(@exidio)
          |> Enum.map(fn dos -> E.format0b(dos, @common[:digit_8]) end)
          |> List.flatten()
          |> my_list_replace_at.(@dout_exidio[do_name], on_off)
          |> Enum.split(@common[:digit_8])
          |> Tuple.to_list()
          |> Enum.map(fn list -> Enum.join(list) end)
          |> Enum.map(fn command -> String.to_integer(command, @common[:digit_2]) end)

        GenServer.cast(@exidio, {:set_do, list_command})

      _ ->
        :error
    end
  end

  @doc """
  DOを操作するコマンドを実行する。

  ## パラメータ
    - command: dout_(exicombo|exidio)であらかじめ設定しているコマンド

  ## 例
      iex> set_dos(:exicombo_initialize)    # => 0b1111
      iex> set_dos(:exidio_initialize)    # => [0b11111111, 0b11111111]
  """
  def set_dos(command) do
    case get_device_name_do(command) do
      @exicombo ->
        {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])
        Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], @dout_exicombo[command]>>)

      @exidio ->
        GenServer.cast(@exidio, {:set_dos, @dout_exidio[command]})

      _ ->
        :error
    end
  end

  @doc """
  デバッグ用。DOを操作するコマンドを実行する。

  ## パラメータ
    - device: `{:global, :exicombo}` or `{:global, :exidio}` を想定
    - command: DOを操作するコマンド

  ## 例
      iex> set_dos({:global, :exicombo}, 0b0110)    # => DO 0と3をOn
      iex> set_dos({:global, :exidio}, [0b01010101, 0b10101010])
  """
  def set_dos(device, command) do
    case device do
      @exicombo ->
        {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])
        Circuits.I2C.write(ref, @common[:device_1], <<@common[:gpio_b], command>>)

      @exidio ->
        GenServer.cast(@exidio, {:set_dos, command})

      _ ->
        :error
    end
  end

  @doc """
  現在のDOを値を読み出す。
  """
  def get_current_dos(device) do
    case device do
      @exicombo ->
        {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])

        {:ok, <<_high_4::4, current_dos::4>>} =
          Circuits.I2C.write_read(
            ref,
            @common[:device_1],
            <<@common[:gpio_b]>>,
            @common[:read_byte_do]
          )

        current_dos

      @exidio ->
        GenServer.call(@exidio, :get_current_dos)

      _ ->
        :error
    end
  end

  @doc """
  exicomboのDIを更新する。

  ## パラメータ
    - state: 現在のstate（get_all_device_status/0と同じ構造）
    - upd_di: 更新したいDIリスト

  ## 例
      iex> get_all_device_status()
      [
        exicombo: %{ai: [218, 370, 199, 480, 761, 1], di: [0, 1, 1, 0, 1, 1, 1, 0]},
        exidio: %{di: [0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]}
      ]
      iex> update_state_exicombo_di(state, [0, 0, 0, 0, 0, 0, 0, 1])
      [
        exicombo: %{ai: [218, 370, 199, 480, 761, 1], di: [0, 0, 0, 0, 0, 0, 0, 0]},
        exidio: %{di: [0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]}
      ]
  """
  def update_state_exicombo_di(state, upd_di) do
    [
      exicombo: %{di: upd_di, ai: state[:exicombo].ai},
      exidio: %{di: state[:exidio].di}
    ]
  end

  @doc """
  exicomboのAIを更新する。

  ## パラメータ
    - state: 現在のstate（get_all_device_status/0と同じ構造）
    - upd_ai: 更新したいAIリスト

  ## 例
      iex> get_all_device_status()
      [
        exicombo: %{ai: [218, 370, 199, 480, 761, 1], di: [0, 1, 1, 0, 1, 1, 1, 0]},
        exidio: %{di: [0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]}
      ]
      iex> update_state_exicombo_ai(state, [0, 0, 0, 0, 0, 100])
      [
        exicombo: %{ai: [0, 0, 0, 0, 0, 100], di: [0, 0, 0, 0, 0, 0, 0, 0]},
        exidio: %{di: [0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]}
      ]
  """
  def update_state_exicombo_ai(state, upd_ai) do
    [
      exicombo: %{di: state[:exicombo].di, ai: upd_ai},
      exidio: %{di: state[:exidio].di}
    ]
  end

  @doc """
  exidioのDIを更新する。

  ## パラメータ
    - state: 現在のstate（get_all_device_status/0と同じ構造）
    - upd_di: 更新したいDIリスト

  ## 例
      iex> get_all_device_status([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
      [
        exicombo: %{ai: [218, 370, 199, 480, 761, 1], di: [0, 1, 1, 0, 1, 1, 1, 0]},
        exidio: %{di: [0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0]}
      ]
      iex> update_state_exicombo_ai(state, [])
      [
        exicombo: %{ai: [0, 0, 0, 0, 0, 100], di: [0, 0, 0, 0, 0, 0, 0, 0]},
        exidio: %{di: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]}
      ]
  """
  def update_state_exidio_di(state, upd_di) do
    [
      exicombo: %{di: state[:exicombo].di, ai: state[:exicombo].ai},
      exidio: %{di: upd_di}
    ]
  end

  @doc """
  Node.connectされているか確認する。

  ## 例
      iex> conn_nodes_ping?()
      true
  """
  def conn_nodes_ping?() do
    node_list = Node.list()

    case length(node_list) do
      0 ->
        false

      _ ->
        node_list
        |> Enum.map(fn node -> Node.ping(node) end)
        |> Enum.all?(fn node_ping_result -> if node_ping_result == :pong, do: true end)
    end
  end

  @doc """
  `__ENV__` から関数名を取得する。
  {function_name, _} = __ENV__.function`

  ## パラメータ
    - env: 関数名

  ## 例
      iex> get_function_name(__ENV__)
      "start_link"
  """
  def get_function_name(env) do
    env.function
    |> Tuple.to_list()
    |> Enum.at(0)
    |> Atom.to_string()
  end

  @doc """
  state_serverで管理している状態を返す。

  ## 例
      iex> [state, new_state] = get_state()
  """
  def get_state() do
    GenServer.call(@state_server, :get_state)
  end

  @doc """
  ログを送る。

  ## パラメータ
    - module_name: モジュール名 `例: __MODULE__`
    - env: `__ENV__`
    - log: ログメッセージ
    - type: Loggerに渡すエラークラス

  ## 例
      iex> send_log(__MODULE__, __ENV__, log)
      iex> send_log(__MODULE__, __ENV__, log, :error)
  """
  def send_log(module_name, env, log, type \\ :info) do
    log = inspect(module_name) <> "." <> get_function_name(env) <> ": " <> inspect(log)

    case type do
      :error -> Logger.error(log)
      :warn -> Logger.warning(log)
      :notice -> Logger.notice(log)
      :info -> Logger.info(log)
      _ -> Logger.error("error: type #{inspect(type)}")
    end
  end
end
