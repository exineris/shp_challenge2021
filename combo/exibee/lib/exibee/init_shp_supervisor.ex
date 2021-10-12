defmodule Exibee.InitShp.Supervisor do
  alias Exibee.Elib, as: E

  def start({flg, result_list}) do
    case [flg, result_list] do
      [:ok, _] ->
        E.send_log(__MODULE__, __ENV__, "Supervisor start!!!")

        children = [
          {Exibee.Valve, {:inlet_valve_control, :inlet_valve_open, :inlet_valve_closed}},
          {Exibee.HealthCheck.StateServer, [{:global, :state_server}, []]},
          {Exibee.HealthCheck.HealthCheckServer, [{:global, :health_check_server}, []]},
          {Exibee.HealthCheck.LogicControllerServer, [{:global, :logic_controller_server}, []]}
        ]

        opts = [strategy: :one_for_one, name: __MODULE__]

        E.send_log(__MODULE__, __ENV__, "#{inspect(result_list)}")

        Supervisor.start_link(children, opts)

      [:error, _] ->
        E.send_log(__MODULE__, __ENV__, "#{inspect(result_list)}")
        {:error, [:error | result_list]}

      [_, _] ->
        E.send_log(__MODULE__, __ENV__, "#{inspect(result_list)}")
        {:error, [:error | result_list]}
    end
  end
end
