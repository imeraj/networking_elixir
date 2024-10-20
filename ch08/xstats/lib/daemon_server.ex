defmodule XStats.DaemonServer do
  @moduledoc false
  use GenServer

  require Logger

  @flush_interval_millisec :timer.seconds(10)

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  defstruct socket: nil, metrics: %{}, flush_io_device: nil

  # callbacks
  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :port)
    flush_io_device = Keyword.get(opts, :flush_io_device, :stdio)

    case :gen_udp.open(port, [:binary, active: true]) do
      {:ok, socket} ->
        :timer.send_interval(@flush_interval_millisec, self(), :flush)
        {:ok, %__MODULE__{socket: socket, flush_io_device: flush_io_device}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(message, attrs)

  def handle_info({:udp, socket, _ip, _port, data}, %__MODULE__{socket: socket} = state) do
    {metrics, _errors} = XStats.Protocol.parse_metrics(data)
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
    case state.metrics[:name] || {:counter, 0} do
      {:counter, counter} ->
        put_in(state.metrics[name], {:counter, counter + value})

      _other ->
        state
    end
  end
end
