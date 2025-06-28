defmodule Chat.Acceptor do
  @moduledoc false
  use GenServer

  require Logger

  defstruct [:listen_socket, :supervisor]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options)
  end

  @impl GenServer
  def init(options) do
    port = Keyword.fetch!(options, :port)

    listen_options = [
      :binary,
      active: :once,
      exit_on_close: false,
      reuseaddr: true,
      backlog: 25
    ]

    {:ok, sup} = DynamicSupervisor.start_link(max_children: 20)

    case :gen_tcp.listen(port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Started Chat server on port #{port}")
        send(self(), :accept)
        {:ok, %__MODULE__{listen_socket: listen_socket, supervisor: sup}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_info(:accept, state) do
    case :gen_tcp.accept(state.listen_socket, 2_000) do
      {:ok, socket} ->
        {:ok, pid} = DynamicSupervisor.start_child(state.supervisor, {Chat.Connection, socket})
        :ok = :gen_tcp.controlling_process(socket, pid)
        send(self(), :accept)
        {:noreply, state}

      {:error, :timeout} ->
        send(self(), :accept)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("TCP accept failed: #{inspect(reason)}")
        {:stop, reason, state}
    end
  end
end
