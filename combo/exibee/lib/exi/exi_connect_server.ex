defmodule Exi.ConnectServer do
  @moduledoc """
  Nerves起動時に `Node.connect()` を受け入れるための準備をする。

  ## 使い方

  application.exに以下を記載する。
  ```
  {Exi.ConnectServer, [node_name, cookie]}
  ```
    - node_name: 自分のノード名
    - cookie: クッキー（共通鍵）

  ## 例
  ```
  {Exi.ConnectServer, ["my_node_name", "comecomeeverybody"]}
  ```
  """
  use GenServer
  require Logger

  @interval_init_ms 1_000

  def start_link(node_option \\ []) do
    # to init/1
    GenServer.start_link(__MODULE__, node_option, name: __MODULE__)
  end

  def init(node_option) do
    set_interval(:init, @interval_init_ms)
    {:ok, node_option}
  end

  def set_interval(msg, ms) do
    # to handle_info/2
    Process.send_after(self(), msg, ms)
  end

  def handle_info(:init, node_option) do
    init_node(eth0_ready?(), node_option)
    {:noreply, node_option}
  end

  defp init_node(true, [node_name, cookie]) do
    node_host = get_ipaddr_eth0_static()
    System.cmd("epmd", ["-daemon"])
    Node.start(:"#{node_name}@#{node_host}")
    Node.set_cookie(:"#{cookie}")

    Logger.info("=== Node.start -> #{node_name}@#{node_host} ===")
    Logger.info("=== Node.set_cookie -> #{cookie} ===")

    case [node_start?(), node_set_cookie?()] do
      [true, true] ->
        Logger.info("=== init_node -> success! Node.start & Node.set ===")
        {:noreply, [node_name, cookie]}

      [_, _] ->
        Logger.info(
          "=== init_node -> false, node_start(#{inspect(node_start?())}), node_set_cookie(#{inspect(node_set_cookie?())}) ==="
        )

        set_interval(:init, @interval_init_ms)
    end
  end

  def node_start?() do
    case Node.self() do
      :nonode@nohost -> false
      _ -> true
    end
  end

  def node_set_cookie?() do
    case Node.get_cookie() do
      :nocookie -> false
      _ -> true
    end
  end

  def eth0_ready?() do
    case get_ipaddr_eth0_static() do
      nil -> false
      _ -> true
    end
  end

  def get_ipaddr_eth0_static() do
    case VintageNet.get_by_prefix(["interface", "eth0", "config"]) do
      [] ->
        nil

      [tuple_int_eth0_config] ->
        tuple_int_eth0_config
        |> (fn {_, list_settings} -> list_settings end).()
        |> Map.get(:ipv4)
        |> Map.get(:address)
    end
  end
end
