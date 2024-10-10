defmodule Chat.AcceptorPool.Listener do
  @moduledoc false

  use GenServer, restart: :transient
  require Logger

  alias Chat.AcceptorPool.AcceptorSupervisor

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link({options, supervisor}) do
    GenServer.start_link(__MODULE__, {options, supervisor})
  end

  @impl true
  def init({options, supervisor}) do
    port = Keyword.fetch!(options, :port)

    listen_options = [
      :binary,
      active: :once,
      exit_on_close: false,
      reuseaddr: true,
      backlog: 25,
      packet: :raw
    ]

    case :gen_tcp.listen(port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Started pooled chat server on port #{port}")
        state = {listen_socket, supervisor}
        {:ok, state, {:continue, :start_acceptor_pool}}

      {:error, reason} ->
        {:stop, {:listen_error, reason}}
    end
  end

  @impl true
  def handle_continue(:start_acceptor_pool, {listen_socket, supervisor} = state) do
    spec = {AcceptorSupervisor, listen_socket: listen_socket}
    {:ok, _} = Supervisor.start_child(supervisor, spec)

    {:noreply, state}
  end
end
