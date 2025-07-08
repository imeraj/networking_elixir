defmodule SillyGame.Server do
  @moduledoc false
  @behaviour WebSock

  require Logger

  defstruct [:phase, :timer_ref]

  @impl WebSock
  def init(_opts) do
    Logger.info("Started WebSocket conenction handler")
    state = schedule_next_tick(%__MODULE__{})
    {:ok, state}
  end

  @impl WebSock
  def handle_info(message, state)

  def handle_info(:tick, %__MODULE__{phase: :idle} = state) do
    Logger.info("Ticked! Client has 1 second to respond")

    timer_ref = Process.send_after(self(), :tick_expired, 1000)
    state = %__MODULE__{state | phase: :ticked, timer_ref: timer_ref}

    {:push, {:text, "ping"}, state}
  end

  def handle_info(:tick_expired, %__MODULE__{phase: :ticked} = state) do
    state = schedule_next_tick(%__MODULE__{state | timer_ref: nil})
    {:push, {:text, "expired"}, state}
  end

  @impl WebSock
  def handle_in(message, state)

  def handle_in({"pong", [opcode: :text]}, %__MODULE__{phase: :ticked} = state) do
    Logger.info("Client responsed in time! You won!")

    state =
      state
      |> cancel_expiration_timer()
      |> schedule_next_tick()

    {:push, {:text, "won"}, state}
  end

  def handle_in({"pong", [opcode: :text]}, %__MODULE__{phase: :idle} = state) do
    Logger.info("Client responsed without being asked!")

    {:push, {:text, "early"}, state}
  end

  defp schedule_next_tick(state) do
    timeout = Enum.random(5_000..30_000)
    Process.send_after(self(), :tick, timeout)
    Logger.info("Scheduled next tick in #{timeout}ms")
    %__MODULE__{state | phase: :idle}
  end

  def cancel_expiration_timer(%__MODULE__{} = state) do
    case Process.cancel_timer(state.timer_ref) do
      time_left when is_integer(time_left) ->
        :ok

      false ->
        receive do
          :tick_expired -> :ok
        after
          0 -> :ok
        end
    end

    %{state | timer_ref: nil}
  end
end
