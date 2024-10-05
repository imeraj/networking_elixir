defmodule TCPEchoServer.Connection do
  @moduledoc false

  use GenServer

  require Logger

  defstruct [:socket, buffer: <<>>]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(socket) do
    GenServer.start_link(__MODULE__, socket, name: __MODULE__)
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
    state = update_in(state.buffer, &(&1 <> data))
    state = handle_new_data(state)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, %__MODULE__{socket: socket} = state) do
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, socket, reason}, %__MODULE__{socket: socket} = state) do
    Logger.error("TCP connection error #{inspect(reason)}")
    {:stop, :normal, state}
  end

  defp handle_new_data(state) do
    case String.split(state.buffer, "\n", parts: 2) do
      [line, rest] ->
        :ok = :gen_tcp.send(state.socket, line <> "\n")
        state = put_in(state.buffer, rest)
        handle_new_data(state)

      _ ->
        state
    end
  end
end