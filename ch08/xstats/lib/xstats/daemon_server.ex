defmodule Xstats.DaemonServer do
  @moduledoc false
  use GenServer

  require Logger

  @flush_inverval_timer :timer.seconds(15)
  defstruct socket: nil, metrics: %{}, flush_io_device: nil

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec fetch_value(GenServer.server(), String.t()) ::
          {:ok, number()} | :error
  def fetch_value(server, name) do
    GenServer.call(server, {:fetch_value, name})
  end

  @impl GenServer
  def init(opts) do
    port = Keyword.fetch!(opts, :port)
    flush_io_device = Keyword.get(opts, :flush_io_device, :stdio)

    case :gen_udp.open(port, [:binary, active: true]) do
      {:ok, socket} ->
        :timer.send_interval(@flush_inverval_timer, self(), :flush)
        {:ok, %__MODULE__{socket: socket, flush_io_device: flush_io_device}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:fetch_value, name}, _from, state) do
    case Map.fetch(state.metrics, name) do
      {:ok, {_type, value}} -> {:reply, {:ok, value}, state}
      :error -> {:reply, :error, state}
    end
  end

  @impl GenServer
  def handle_info(message, state)

  def handle_info({:udp, socket, _ip, _port, data}, %__MODULE__{socket: socket} = state) do
    {metrics, _errors} = Xstats.Protocol.parse_metrics(data)
    state = Enum.reduce(metrics, state, &process_metric/2)
    {:noreply, state}
  end

  def handle_info(:flush, %__MODULE__{} = state) do
    IO.puts(state.flush_io_device, """
    ===============
    Current metrics
    ===============
    """)

    state =
      update_in(state.metrics, fn metrics ->
        Map.new(metrics, fn
          {name, {:gauge, value}} ->
            IO.puts(state.flush_io_device, "#{name}:\t#{value}")
            {name, {:gauge, value}}

          {name, {:counter, value}} ->
            IO.puts(state.flush_io_device, "#{name}:\t#{value}")
            {name, {:counter, 0}}
        end)
      end)

    IO.puts(state.flush_io_device, "\n\n\n")
    {:noreply, state}
  end

  defp process_metric({:gauge, name, value}, %__MODULE__{} = state) do
    put_in(state.metrics[name], {:gauge, value})
  end

  defp process_metric({:counter, name, value}, %__MODULE__{} = state) do
    case state.metrics[name] || {:counter, 0} do
      {:counter, current} ->
        put_in(state.metrics[name], {:counter, current + value})

      _ ->
        state
    end
  end
end
