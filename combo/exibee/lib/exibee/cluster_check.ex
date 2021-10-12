defmodule Exibee.ClusterCheck do
  use GenServer
  require Logger

  alias Exibee.Elib, as: E

  @cluster_mulfunction 1

  @doc """
  クラスターチェックをおこなう。

  ## パラメータ
    - interval_alive_ms: クラスターチェックをする間隔（ミリ秒）

  ## 例
      iex> Exibee.ClusterCheck.start_link([60_000])    # => 60秒ごとにチェック
  """
  def start_link([interval_alive_ms] \\ []) do
    case [E.conn_nodes_ping?()] do
      [true] ->
        Process.sleep(1_000)
        log = "started"
        E.send_log(__MODULE__, __ENV__, log)
        GenServer.start_link(__MODULE__, interval_alive_ms, name: __MODULE__)

      [_] ->
        Exibee.ClusterCheck.start_link([interval_alive_ms])
    end
  end

  def init(interval_alive_ms) do
    set_interval(:check_mulfunction, interval_alive_ms)
    {:ok, interval_alive_ms}
  end

  def stop(_) do
    GenServer.stop(__MODULE__)
  end

  def set_interval(msg, interval_alive_ms) do
    Process.send_after(self(), msg, interval_alive_ms)
  end

  def handle_info(:check_mulfunction, interval_alive_ms) do
    check_mulfunction(interval_alive_ms)
    {:noreply, interval_alive_ms}
  end

  def check_mulfunction(interval_alive_ms) do
    case [E.conn_nodes_ping?()] do
      [true] ->
        set_interval(:check_mulfunction, interval_alive_ms)

      [_] ->
        log = "CLUSTER MULFUNCTION ERROR!!"
        E.send_log(__MODULE__, __ENV__, log, :error)

        E.set_do(:exicombo_do_0, @cluster_mulfunction)

        __MODULE__.stop(__MODULE__)
    end
  end

  def terminate(reason, _) do
    log = inspect(reason)
    E.send_log(__MODULE__, __ENV__, log, :error)

    reason
  end
end
