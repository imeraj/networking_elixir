defmodule Chat.Acceptor do
  @moduledoc false
  use GenServer
  require Logger

  defstruct [:listen_socket, :supervisor]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  # Callbacks
  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :port)

    listen_options = [
      :binary,
      active: :once,
      exit_on_close: false,
      reuseaddr: true,
      backlog: 25,
      packet: :raw
    ]

    {:ok, sup} = DynamicSupervisor.start_link(max_children: 20)

    case :gen_tcp.listen(port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Started chat server on port #{port}")
        send(self(), :accept)
        {:ok, %__MODULE__{listen_socket: listen_socket, supervisor: sup}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:accept, %__MODULE__{} = state) do
    %{listen_socket: listen_socket, supervisor: supervisor} = state

    case :gen_tcp.accept(listen_socket, 2_000) do
      {:ok, socket} ->
        Logger.info("Accepted connection on #{inspect(socket)}")
        {:ok, pid} = DynamicSupervisor.start_child(supervisor, {Chat.Connection, socket})
        :ok = :gen_tcp.controlling_process(socket, pid)
        send(self(), :accept)
        {:noreply, state}

      {:error, :timeout} ->
        send(self(), :accept)
        {:noreply, state}

      {:error, reason} ->
        {:stop, reason, state}
    end
  end
end
