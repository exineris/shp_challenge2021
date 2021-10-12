defmodule Exi.GPIO do
  @behaviour GenServer
  #  use GenServer
  require Circuits.GPIO
  require Logger

  def start_link(pname, gpio_no, in_out, ppid \\ []) do
    # Logger.debug(
    Logger.info(
      "#{__MODULE__} start_link: #{inspect(pname)}, #{gpio_no}, #{in_out}, #{inspect(ppid)}"
    )

    GenServer.start_link(__MODULE__, {gpio_no, in_out, ppid}, name: pname)
  end

  def write(pname, true), do: GenServer.cast(pname, {:write, 1})
  def write(pname, false), do: GenServer.cast(pname, {:write, 0})
  def write(pname, val), do: GenServer.cast(pname, {:write, val})

  def read(pname), do: GenServer.call(pname, :read)
  def stop(pname), do: GenServer.stop(pname)

  @impl GenServer
  def init({gpio_no, in_out = :input, ppid}) do
    # Logger.debug("#{__MODULE__} init_open: #{gpio_no}, #{in_out} ")
    Logger.info("#{__MODULE__} init_open: #{gpio_no}, #{in_out} ")
    {:ok, gpioref} = Circuits.GPIO.open(gpio_no, in_out)
    Circuits.GPIO.set_interrupts(gpioref, :both, receiver: ppid)
    {:ok, gpioref}
  end

  @impl GenServer
  def init({gpio_no, in_out = :output, _ppid}) do
    # Logger.debug("#{__MODULE__} init_open: #{gpio_no}, #{in_out} ")
    Logger.info("#{__MODULE__} init_open: #{gpio_no}, #{in_out} ")
    Circuits.GPIO.open(gpio_no, in_out)
  end

  @impl GenServer
  def handle_cast({:write, val}, gpioref) do
    # Logger.debug("#{__MODULE__} :write #{val} ")
    Circuits.GPIO.write(gpioref, val)
    {:noreply, gpioref}
  end

  @impl GenServer
  def handle_call(:read, _from, gpioref) do
    {:reply, {:ok, Circuits.GPIO.read(gpioref)}, gpioref}
  end

  # @impl GenServer
  # def handle_info(msg, gpioref) do
  #   Logger.info("#{__MODULE__} get_message: #{inspect(msg)}")
  #   Circuits.GPIO.set_interrupts(gpioref, :both)
  #   {:noreply, gpioref}
  # end

  @impl GenServer
  def terminate(reason, gpioref) do
    # Logger.debug("#{__MODULE__} terminate: #{inspect(reason)}")
    Logger.info("#{__MODULE__} terminate: #{inspect(reason)}")
    Circuits.GPIO.close(gpioref)
    reason
  end
end
