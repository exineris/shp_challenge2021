defmodule Exibee.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Exibee.Supervisor]

    children =
      [
        # Children for all targets
        # Starts a worker by calling: Exibee.Worker.start_link(arg)
        # {Exibee.Worker, arg},
      ] ++ children(target())

    Exibee.InitDevice.start()
    Supervisor.start_link(children, opts)
    Exibee.InitShp.start()
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: Exibee.Worker.start_link(arg)
      # {Exibee.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: Exibee.Worker.start_link(arg)
      # {Exibee.Worker, arg},
      {Exi.ConnectServer, ["exicombo", "comecomeeverybody"]},
      {Exibee.ClusterCheck, [60_000]}
    ]
  end

  def target() do
    Application.get_env(:exibee, :target)
  end
end
