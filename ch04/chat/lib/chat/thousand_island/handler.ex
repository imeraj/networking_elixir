defmodule Chat.ThousandIsland.Handler do
  @moduledoc false
  use ThousandIsland.Handler

  alias Chat.Messages.{Register, Broadcast}
  alias Chat.{BroadcastRegistry, UsernameRegistry}

  require Logger

  defstruct [:username, buffer: <<>>]

  @impl ThousandIsland.Handler
  def handle_connection(_socket, [] = _options) do
    {:continue, %__MODULE__{}}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, _socket, state) do
    state = update_in(state.buffer, &(&1 <> data))
    handle_new_data(state)
  end

  @impl GenServer
  def handle_info({:broadcast, %Broadcast{} = message}, {socket, state}) do
    encoded_message = Chat.Protocol.encode_message(message)
    :ok = ThousandIsland.Socket.send(socket, encoded_message)
    {:noreply, {socket, state}}
  end

  defp handle_new_data(state) do
    case Chat.Protocol.decode_message(state.buffer) do
      {:ok, message, rest} ->
        state = put_in(state.buffer, rest)

        case handle_message(message, state) do
          {:ok, state} -> handle_new_data(state)
          :error -> {:close, state}
        end

      :incomplete ->
        {:continue, state}

      :error ->
        Logger.error("Received invalid data, closing connection")
        {:close, state}
    end
  end

  defp handle_message(%Register{username: username}, %__MODULE__{username: nil} = state) do
    {:ok, _} = Registry.register(BroadcastRegistry, :broadcast, :no_value)
    {:ok, _} = Registry.register(UsernameRegistry, username, :no_value)

    {:ok, put_in(state.username, username)}
  end

  defp handle_message(%Register{}, _state) do
    Logger.error("Invalid Register message, had already received one")
    :error
  end

  defp handle_message(%Broadcast{} = _message, %__MODULE__{username: nil}) do
    Logger.error("Invalid Broadcast message, had not received a Register")
    :error
  end

  defp handle_message(%Broadcast{} = message, state) do
    sender = self()
    message = %Broadcast{message | from_username: state.username}

    Registry.dispatch(BroadcastRegistry, :broadcast, fn entries ->
      Enum.each(entries, fn {pid, _value} ->
        if sender != pid do
          send(pid, {:broadcast, message})
        end
      end)
    end)

    {:ok, state}
  end
end
