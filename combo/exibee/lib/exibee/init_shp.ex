defmodule Exibee.InitShp do
  @moduledoc """
  起動時に指定小水力発電所の起動処理を行う。
  """

  require Logger

  alias Exibee.Elib, as: E
  alias Exibee.LogicController, as: LC

  def start(result_list \\ []) do
    log = "start"

    case [E.conn_nodes_ping?()] do
      [true] ->
        Process.sleep(1_000)
        E.send_log(__MODULE__, __ENV__, log)

        result_list
        |> init()
        |> parallel_off_activated()
        |> check_init_health()
        |> parallel_off_deactivated()
        |> check_inverter_ready()
        |> inverter_operation_order_start()
        |> Exibee.InitShp.Supervisor.start()

      [_] ->
        Exibee.InitShp.start(result_list)
    end
  end

  @doc """
  初期化処理
  """
  def init(result_list) do
    log = "Init Shp Start"
    E.send_log(__MODULE__, __ENV__, log)

    # 発電所が期待するDOの初期化
    LC.do_initialize()
    log = "Init Shp DO Initialize"
    E.send_log(__MODULE__, __ENV__, log)

    {:ok, [:ok | result_list]}
  end

  @doc """
  解列処理
  """
  def parallel_off_activated({flg, result_list}) do
    case [flg, result_list] do
      [:ok, _] ->
        # 解列処理
        LC.parallel_off(:activated)

        # 解列しているか確認
        case LC.check_parallel_off_relay_activated?() do
          true ->
            log = "Init Shp parallel off relay is activated"
            E.send_log(__MODULE__, __ENV__, log)
            {:ok, [:ok | result_list]}

          _ ->
            log = "Init Shp Err parallel off relay not activated"
            E.send_log(__MODULE__, __ENV__, log, :error)
            cluster_error()
            {:error, [:error | result_list]}
        end

      [:error, _] ->
        {:error, [:error | result_list]}

      [_, _] ->
        {:error, [:error | result_list]}
    end
  end

  @doc """
  起動時のヘルスチェック
  """
  def check_init_health({flg, result_list}) do
    case [flg, result_list] do
      [:ok, _] ->
        case init_health?() do
          true ->
            log = "Init Shp healthy"
            E.send_log(__MODULE__, __ENV__, log)
            {:ok, [:ok | result_list]}

          _ ->
            log = "Init Shp Err not healthy"
            E.send_log(__MODULE__, __ENV__, log, :error)
            cluster_error()
            {:error, [:error | result_list]}
        end

      [:error, _] ->
        {:error, [:error | result_list]}

      [_, _] ->
        {:error, [:error | result_list]}
    end
  end

  # 並列処理を行う
  def parallel_off_deactivated({flg, result_list}) do
    case [flg, result_list] do
      [:ok, _] ->
        # 並列処理
        LC.parallel_off(:deactivated)

        # 並列しているか確認
        case LC.check_parallel_off_relay_activated?() do
          false ->
            log = "Init Shp parallel off relay is deactivated"
            E.send_log(__MODULE__, __ENV__, log)
            {:ok, [:ok | result_list]}

          _ ->
            log = "Init Shp Err parallel off relay not deactivated"
            E.send_log(__MODULE__, __ENV__, log, :error)
            cluster_error()
            {:error, [:error | result_list]}
        end

      [:error, _] ->
        {:error, [:error | result_list]}

      [_, _] ->
        {:error, [:error | result_list]}
    end
  end

  @doc """
  インバーター運転準備完了チェック
  """
  def check_inverter_ready({flg, result_list}) do
    case [flg, result_list] do
      [:ok, _] ->
        case LC.check_inverter_ready?() do
          true ->
            log = "Init Shp inverter is ready"
            E.send_log(__MODULE__, __ENV__, log)
            {:ok, [:ok | result_list]}

          _ ->
            log = "Init Shp Err inverter not ready"
            E.send_log(__MODULE__, __ENV__, log, :error)
            cluster_error()
            {:error, [:error | result_list]}
        end

      [:error, _] ->
        {:error, [:error | result_list]}

      [_, _] ->
        {:error, [:error | result_list]}
    end
  end

  @doc """
  インバーター起動
  """
  def inverter_operation_order_start({flg, result_list}) do
    case [flg, result_list] do
      [:ok, _] ->
        # インバーター起動処理
        LC.inverter_operation_order(:start)

        # ドライバー・インバーターが運転中か確認
        case LC.check_driver_inverter_running?() do
          true ->
            log = "Init Shp perfect condition!!!"
            E.send_log(__MODULE__, __ENV__, log)
            {:ok, [:ok | result_list]}

          _ ->
            log = "Init Shp Err inverter operation order can't started"
            E.send_log(__MODULE__, __ENV__, log, :error)
            cluster_error()
            {:error, [:error | result_list]}
        end

      [:error, _] ->
        {:error, [:error | result_list]}

      [_, _] ->
        {:error, [:error | result_list]}
    end
  end

  ##########################################################################
  def init_health?() do
    all_device_status = E.get_all_device_status()
    check_dilist = all_device_status[:exicombo].di ++ all_device_status[:exidio].di

    log = "init healt is: #{inspect(check_dilist)}"
    E.send_log(__MODULE__, __ENV__, log)

    case check_dilist do
      [_, _, 1, _, 1, 0, 1, 1, _, _, 1, _, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0] ->
        true

      _ ->
        false
    end
  end

  def cluster_error() do
    log = "Init Shp Error"
    E.send_log(__MODULE__, __ENV__, log, :error)
    E.set_dos(:exicombo_cluster_mulfunction)
    # Nerves.Runtime.poweroff()
  end
end
