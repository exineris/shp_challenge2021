defmodule Exibee.Elib do
  require Logger

  alias Exibee.Elib, as: E

  @common Application.get_env(:exibee, :common)
  # @din_exidio Application.get_env(:exibee, :din_exidio)
  @dout_exicombo Application.get_env(:exibee, :dout_exicombo)
  @dout_exidio Application.get_env(:exibee, :dout_exidio)
  @exicombo @common[:exicombo]
  @exidio @common[:exidio]

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
    {function_name, _} = __ENV__.function

    leds = ["green", "orange", "yellow", "red"]
    log = Enum.map(leds, fn led -> E.set_led(led, behavior) end)

    E.send_log(__MODULE__, function_name, log)
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
    {function_name, _} = __ENV__.function

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
    E.send_log(__MODULE__, function_name, log)
  end

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
  2つのDIリストから指定ビットを取得しリストで返す。

  ## パラメータ
    - src_di 変更前DIリスト（8ビット）
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
    Enum.count(src_di) - 1 - pin
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
  DIの状態をリストで返す。右端がDI0となる。

  ## 例
      iex> get_all_dis()
      [1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0]
  """
  def get_all_dis() do
    {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])

    # すべてのDIの値を読み出し
    gpio_a =
      Circuits.I2C.write_read!(
        ref,
        @common[:device_di],
        <<@common[:gpio_a]>>,
        @common[:read_byte_di]
      )
      |> E.to_binary_decode_unsigned()
      |> E.format0b(@common[:digit_8])

    gpio_b =
      Circuits.I2C.write_read!(
        ref,
        @common[:device_di],
        <<@common[:gpio_b]>>,
        @common[:read_byte_di]
      )
      |> E.to_binary_decode_unsigned()
      |> E.format0b(@common[:digit_8])

    gpio_b ++ gpio_a
  end

  @doc """
  現在のDOの値を読み出す。
  """
  def get_current_dos() do
    {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])

    {:ok, <<current_dos_low>>} =
      Circuits.I2C.write_read(
        ref,
        @common[:device_do],
        <<@common[:gpio_a]>>,
        @common[:read_byte_do]
      )

    {:ok, <<current_dos_high>>} =
      Circuits.I2C.write_read(
        ref,
        @common[:device_do],
        <<@common[:gpio_b]>>,
        @common[:read_byte_do]
      )

    [current_dos_high, current_dos_low]
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
  DOに出力する。

  ## パラメータ
    - list_command: [上位8ビット, 下位8ビット]

  ## 例
      iex> set_do([91, 252])    # => [0b01011011, 0b11111100]と同じ
  """
  def set_do(list_command) do
    {:ok, ref} = Circuits.I2C.open(@common[:i2c_bus])

    [command_b, command_a] = list_command

    [
      Circuits.I2C.write(ref, @common[:device_do], <<@common[:gpio_a], command_a>>),
      Circuits.I2C.write(ref, @common[:device_do], <<@common[:gpio_b], command_b>>)
    ]
  end

  @doc """
  DOにコマンドを送信する。

  ## パラメータ
    - list_command: [上位8ビット, 下位8ビット]

  ## 例
      iex> set_dos([91, 252])    # => [0b01011011, 0b11111100]と同じ
  """
  def set_dos(list_command) do
    set_do(list_command)
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
