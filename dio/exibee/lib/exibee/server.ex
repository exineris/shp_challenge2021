defmodule Exibee.Server do
  use GenServer
  require Logger

  alias Exibee.Elib, as: E

  @common Application.get_env(:exibee, :common)

  @gpio_interrupt_di_1 @common[:gpio_interrupt_di_1]
  @gpio_interrupt_di_2 @common[:gpio_interrupt_di_2]
  @gpio_falling @common[:gpio_falling]
  @state_server @common[:state_server]

  def start_link(pname, state \\ []) do
    log = inspect(pname)
    E.send_log(__MODULE__, __ENV__, log)

    GenServer.start_link(__MODULE__, state, name: pname)
  end

  def init(state) do
    log = inspect(state)
    E.send_log(__MODULE__, __ENV__, log)

    Exi.GPIO.start_link(:di_1, @gpio_interrupt_di_1, :input, self())
    Exi.GPIO.start_link(:di_2, @gpio_interrupt_di_2, :input, self())

    {:ok, state}
  end

  def handle_call(:get_all_dis, _from, state) do
    log = ":get_all_dis, state: #{inspect(state)}"
    E.send_log(__MODULE__, __ENV__, log)

    {:reply, E.get_all_dis(), state}
  end

  def handle_call(:get_current_dos, _from, state) do
    log = ":get_current_dos, state: #{inspect(state)}"
    E.send_log(__MODULE__, __ENV__, log)

    {:reply, E.get_current_dos(), state}
  end

  def handle_cast({:set_do, list_command}, state) do
    log = "{:set_do, #{inspect(list_command)}}, state: #{inspect(state)}"
    E.send_log(__MODULE__, __ENV__, log)

    E.set_do(list_command)

    {:noreply, state}
  end

  def handle_cast({:set_dos, list_command}, state) do
    log = "{:set_dos, #{inspect(list_command)}}, state: #{inspect(state)}"
    E.send_log(__MODULE__, __ENV__, log)

    E.set_dos(list_command)

    {:noreply, state}
  end

  def handle_info(
        {:circuits_gpio, @gpio_interrupt_di_1, _time, @gpio_falling},
        state
      ) do
    log = "get_message: GPIO interrupts #{@gpio_interrupt_di_1}"
    E.send_log(__MODULE__, __ENV__, log)

    GenServer.cast(@state_server, {:exidio_dis, E.get_all_dis()})

    {:noreply, state}
  end

  def handle_info(
        {:circuits_gpio, @gpio_interrupt_di_2, _time, @gpio_falling},
        state
      ) do
    log = "get_message: GPIO interrupts #{@gpio_interrupt_di_2}"
    E.send_log(__MODULE__, __ENV__, log)

    GenServer.cast(@state_server, {:exidio_dis, E.get_all_dis()})

    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
