defmodule Exibee.LogicController do
  require Logger

  alias Exibee.Elib, as: E
  alias Exibee.Valve, as: V

  @common Application.get_env(:exibee, :common)
  @health_check_server @common[:health_check_server]
  @parallel_off_sleep 5000
  @inverter_control_sleep 5000

  # 運転ボタン押下
  def start_button_down() do
    log = "start button down"
    E.send_log(__MODULE__, __ENV__, log)

    # インバーターが運転されていれば入力弁を開ける
    case check_driver_inverter_running?() do
      true ->
        log = "let valve open"
        E.send_log(__MODULE__, __ENV__, log)
        # 入力弁開
        V.open()

      _ ->
        log = "start process fail"
        E.send_log(__MODULE__, __ENV__, log)
    end
  end

  # 停止ボタン押下
  def stop_button_down() do
    log = "stop button down"
    E.send_log(__MODULE__, __ENV__, log)
    # 入力弁を閉じる
    V.close()
  end

  # 緊急停止ボタン押下
  def emergency_button_down() do
    log = "emergency button down"
    E.send_log(__MODULE__, __ENV__, log)

    # 解列処理
    pinpoint_parallel_off(:activated)

    # 入力弁を閉じる
    V.close()

    # 解列しているか確認
    case check_parallel_off_relay_activated?() do
      true ->
        log = "emergency parallel off relay is activated"
        E.send_log(__MODULE__, __ENV__, log)
        true

      _ ->
        log = "emergency process fail parallel off relay not activated"
        E.send_log(__MODULE__, __ENV__, log, :error)
        false
    end
  end

  def emergency_button_up() do
    log = "emergency button up"
    E.send_log(__MODULE__, __ENV__, log)
    # 並列処理
    pinpoint_parallel_off(:deactivated)

    case check_parallel_off_relay_activated?() do
      false ->
        # インバーター異常reset"
        pinpoint_inverter_error_reset()

        # インバーター起動
        pinpoint_inverter_operation_order(:start)

        result_list = [
          check_inverter_ready?(),
          check_driver_inverter_running?(),
          V.reset_error()
        ]

        case result_list do
          [true, true, :ok] ->
            log = "emergency button up success"
            E.send_log(__MODULE__, __ENV__, log)
            true

          _ ->
            log = "emergency button up process fail"
            E.send_log(__MODULE__, __ENV__, log)
            GenServer.cast(@health_check_server, {:update_malfunction, true})
            false
        end

      _ ->
        log = "emergency button up process fail"
        E.send_log(__MODULE__, __ENV__, log)
        GenServer.cast(@health_check_server, {:update_malfunction, true})
        false
    end
  end

  # ヘルスチェック異常
  def mulfunction() do
    log = "mulfunction"
    E.send_log(__MODULE__, __ENV__, log)

    # 入力弁を閉じる
    V.close()
  end

  @doc """
  発電所が期待するDOの初期化を行う。

  ## パラメータ
    -

  ## 例
      iex> Exibee.LogicController.do_initialize()
  """
  def do_initialize() do
    E.set_dos(:exicombo_initialize)
    E.set_dos(:exidio_initialize)
  end

  @doc """
  解列・並列処理を行う。
  パルス出力 (0.5s以上)が必要
  OLAT0=0 で ON（接点コンタクト）、デフォルトは 1 で OFF （接点開放）、1 → 0 → 1 を行うことで並列/解列

  ## パラメータ
    - :deactivated 並列処理
    - :activated 解列処理

  ## 例
      iex> Exibee.LogicController.parallel_off(:deactivated)
      iex> Exibee.LogicController.parallel_off(:activated)
  """
  def parallel_off(:deactivated) do
    log = "deactivated"
    E.send_log(__MODULE__, __ENV__, log)

    # 並列処理
    E.set_dos(:exidio_initialize)
    Process.sleep(@parallel_off_sleep)
    E.set_dos(:exidio_parallel_off_relay_deactivated)
    Process.sleep(@parallel_off_sleep)
    E.set_dos(:exidio_initialize)
  end

  def parallel_off(:activated) do
    log = "activated"
    E.send_log(__MODULE__, __ENV__, log)

    # 解列処理
    E.set_dos(:exidio_initialize)
    Process.sleep(@parallel_off_sleep)
    E.set_dos(:exidio_parallel_off_relay_activated)
    Process.sleep(@parallel_off_sleep)
    E.set_dos(:exidio_initialize)
  end

  @doc """
  他のDOの出力状態を維持したまま解列・並列処理を行う。
  パルス出力 (0.5s以上)が必要
  OLAT0=0 で ON（接点コンタクト）、デフォルトは 1 で OFF （接点開放）、1 → 0 → 1 を行うことで並列/解列
  解列：並列のdoをoff後、1 → 0 → 1 を行う
  並列：解列のdoをoff後、1 → 0 → 1 を行う

  ## パラメータ
    - :deactivated 並列処理
    - :activated 解列処理

  ## 例
      iex> Exibee.LogicController.pinpoint_parallel_off(:deactivated)
      iex> Exibee.LogicController.pinpoint_parallel_off(:activated)
  """
  def pinpoint_parallel_off(:deactivated) do
    log = "pinpoint deactivated"
    E.send_log(__MODULE__, __ENV__, log)

    # 解列doをoff(1)
    E.set_do(:exidio_do_3, 1)

    # 並列処理
    E.set_do(:exidio_do_2, 1)
    Process.sleep(@parallel_off_sleep)
    E.set_do(:exidio_do_2, 0)
    Process.sleep(@parallel_off_sleep)
    E.set_do(:exidio_do_2, 1)
  end

  def pinpoint_parallel_off(:activated) do
    log = "pipoint activated"
    E.send_log(__MODULE__, __ENV__, log)

    # 並列doをoff(1)
    E.set_do(:exidio_do_2, 1)

    # 解列処理
    E.set_do(:exidio_do_3, 1)
    Process.sleep(@parallel_off_sleep)
    E.set_do(:exidio_do_3, 0)
    Process.sleep(@parallel_off_sleep)
    E.set_do(:exidio_do_3, 1)
  end

  @doc """
  inverter起動処理を行う。
  InitShpから実行される

  ## パラメータ
    - :start　起動処理

  ## 例
      iex> Exibee.LogicController.inverter_operation_order(:start)
  """
  def inverter_operation_order(:start) do
    log = "inverter operation order"
    E.send_log(__MODULE__, __ENV__, log)

    # インバーター起動
    E.set_dos(:exicombo_inverter_operation_order)
    Process.sleep(@inverter_control_sleep)
    # インバーター起動後開放
    E.set_dos(:exicombo_initialize)
  end

  @doc """
  他のDOの出力状態を維持したままinverter起動処理を行う。

  ## パラメータ
    - :start　起動処理

  ## 例
      iex> Exibee.LogicController.pinpoint_inverter_operation_order(:start)
  """
  def pinpoint_inverter_operation_order(:start) do
    log = "pinpoint inverter operation order start"
    E.send_log(__MODULE__, __ENV__, log)

    # インバーター起動
    E.set_do(:exicombo_do_1, 0)
    Process.sleep(@inverter_control_sleep)
    # インバーター起動後開放
    E.set_do(:exicombo_do_1, 1)
  end

  @doc """
  他のDOの出力状態を維持したままinverter異常のresetを行う。

  ## パラメータ
  ## 例
      iex> Exibee.LogicController.pinpoint_inverter_error_reset()
  """
  def pinpoint_inverter_error_reset() do
    log = "pinpoint inverter error reset"
    E.send_log(__MODULE__, __ENV__, log)

    # inverter異常のreset
    E.set_do(:exicombo_do_2, 0)
    Process.sleep(@inverter_control_sleep)
    # rest後開放
    E.set_do(:exicombo_do_2, 1)
  end

  @doc """
  インバーター運転準備完了チェック

  ## パラメータ
  ## 戻り値
    - :true インバーター運転準備完了
    - :false インバーター運転準備未完了
  ## 例
      iex> Exibee.LogicController.check_inverter_ready?
  """
  def check_inverter_ready?() do
    if E.get_di(:inverter_ready) == 0 do
      log = "inverter is ready"
      E.send_log(__MODULE__, __ENV__, log)
      true
    else
      log = "inverter not ready"
      E.send_log(__MODULE__, __ENV__, log)
      false
    end
  end

  @doc """
  ドライバー・インバーター運転中チェック

  ## パラメータ
  ## 戻り値
    - :true ドライバー・インバーター運転中
    - :false ドライバー・インバーターのどちらかが運転中ではない
  ## 例
      iex> Exibee.LogicController.check_driver_inverter_running?
  """
  def check_driver_inverter_running?() do
    # ドライバーインバーター運転中を確認
    if E.get_di(:driver_inverter_running) == 0 do
      log = "driver inverter is running"
      E.send_log(__MODULE__, __ENV__, log)
      true
    else
      log = "driver or inverter is not running"
      E.send_log(__MODULE__, __ENV__, log)
      false
    end
  end

  @doc """
  解列/並列チェック

  ## パラメータ
  ## 戻り値
    - :true 解列中
    - :false 並列中
  ## 例
      iex> Exibee.LogicController.check_parallel_off_relay_activated?
  """
  def check_parallel_off_relay_activated?() do
    # 解列用リレー作動を確認
    if E.get_di(:parallel_off_relay_activated) == 0 do
      log = "parallel off relay is activated"
      E.send_log(__MODULE__, __ENV__, log)
      true
    else
      log = "parallel off relay is deactivated"
      E.send_log(__MODULE__, __ENV__, log)
      false
    end
  end
end
