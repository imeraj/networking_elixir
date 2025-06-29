defmodule Xstats.Reporter do
  @moduledoc false
  use GenServer

  require Logger

  @mtu 512

  defstruct [:socket, :dest_port]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec increment_counter(GenServer.server(), String.t(), number()) :: :ok
  def increment_counter(server, name, value) do
    GenServer.cast(server, {:send_metric, {:counter, name, value}})
  end

  @spec set_gauge(GenServer.server(), String.t(), number()) :: :ok
  def set_gauge(server, name, value) do
    GenServer.cast(server, {:send_metric, {:gauge, name, value}})
  end

  @impl GenServer
  def init(opts) do
    dest_port = Keyword.fetch!(opts, :port)

    case :gen_udp.open(0, [:binary]) do
      {:ok, socket} ->
        state = %__MODULE__{socket: socket, dest_port: dest_port}
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_cast({:send_metric, metric}, %__MODULE__{} = state) do
    iodata = Xstats.Protocol.encode_metric(metric)

    if IO.iodata_length(iodata) > @mtu do
      Logger.error("Metric data too large: #{IO.iodata_length(iodata)} bytes")
      {:noreply, state}
    else
      _ = :gen_udp.send(state.socket, ~c'localhost', state.dest_port, iodata)
    end

    {:noreply, state}
  end
end
