defmodule Chat.Connection do
  @moduledoc false

  use GenServer, restart: :temporary
  alias Chat.Message.Register

  require Logger

  defstruct [:socket, :username, buffer: <<>>]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket)
  end

  # callbacks
  @impl true
  def init(socket) do
    state = %__MODULE__{socket: socket}
    {:ok, state}
  end

  @impl true
  def handle_info(message, state)

  def handle_info({:tcp, socket, data}, %__MODULE__{socket: socket} = state) do
    :ok = :inet.setopts(socket, active: :once)
    state = update_in(state.buffer, &(&1 <> data))
    handle_new_data(state)
  end

  def handle_info({:tcp_closed, socket}, %__MODULE__{socket: socket} = state) do
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, socket, reason}, %__MODULE__{socket: socket} = state) do
    Logger.error("TCP connection error #{inspect(reason)}")
    {:stop, :normal, state}
  end

  # Private functions
  defp handle_new_data(state) do
    case Chat.Protocol.decode_message(state.buffer) do
      {:ok, message, rest} ->
        state = put_in(state.buffer, rest)

        case handle_message(message, state) do
          {:ok, state} -> handle_new_data(state)
          :error -> {:stop, :normal, state}
        end

      :incomplete ->
        {:noreply, state}

      :error ->
        Logger.error("Received invalid data, closing connection")
        {:stop, :normal, state}
    end
  end

  defp handle_message(%Register{username: username}, %__MODULE__{username: nil} = state) do
    {:ok, put_in(state.username, username)}
  end

  defp handle_message(%Register{}, _state) do
    Logger.error("Invalid Register message, had already received one")
    :error
  end
end
