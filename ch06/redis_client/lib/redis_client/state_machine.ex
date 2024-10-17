defmodule RedisClient.StateMachine do
  @moduledoc false
  @behaviour :gen_statem

  alias RedisClient.RESP
  require Logger

  # The "data" (that is, the equivalent of the "state" in a GenServer).
  defstruct [:host, :port, :socket, :continuation, queue: :queue.new()]

  @backoff_time 1_000

  @spec start_link(keyword()) :: :gen_statem.start_ret()
  def start_link(opts) do
    :gen_statem.start_link(__MODULE__, opts, _gen_statem_options = [])
  end

  @spec command(pid(), [String.t()], timeout()) :: {:ok, term()} | {:error, term()}
  def command(pid, command, timeout \\ 5000) do
    :gen_statem.call(pid, {:command, command}, timeout)
  end

  # Callbacks
  @impl :gen_statem
  def callback_mode, do: [:state_functions, :state_enter]

  @impl :gen_statem
  def init(opts) do
    data = %__MODULE__{
      host: Keyword.fetch!(opts, :host),
      port: Keyword.fetch!(opts, :port)
    }

    actions = [{:next_event, :internal, :connect}]
    {:ok, :disconnected, data, actions}
  end

  ## Disconnected state
  def disconnected(:internal, :connect, data) do
    opts = [:binary, active: :once]

    case :gen_tcp.connect(data.host, data.port, opts, 5_000) do
      {:ok, socket} ->
        data = %__MODULE__{data | socket: socket}
        {:next_state, :connected, data}

      {:error, reason} ->
        Logger.error("Failed to connect: #{:inet.format_error(reason)}")
        timer_action = {{:timeout, :reconnect}, @backoff_time, nil}
        {:keep_state_and_data, [timer_action]}
    end
  end

  def disconnected(:enter, :disconnected, _data) do
    :keep_state_and_data
  end

  def disconnected(:enter, :connected, data) do
    actions =
      for caller <- :queue.to_list(data.queue) do
        {:reply, caller, {:error, :disconnected}}
      end

    data = %__MODULE__{data | queue: :queue.new(), socket: nil, continuation: nil}
    {:keep_state, data, actions}
  end

  def disconnected({:timeout, :reconnect}, nil, _data) do
    actions = [{:next_event, :internal, :connect}]
    {:keep_state_and_data, actions}
  end

  def disconnected({:call, from}, {:command, _command}, _data) do
    actions = [{:reply, from, {:error, :disconnected}}]
    {:keep_state_and_data, actions}
  end

  ## Connected state
  def connected(:enter, :disconnected, _data) do
    actions = [{{:timeout, :reconenct}, :cancel}]
    {:keep_state_and_data, actions}
  end

  def connected({:call, from}, {:command, command}, data) do
    :ok = :gen_tcp.send(data.socket, RESP.encode(command))
    data = update_in(data.queue, &:queue.in(from, &1))
    {:keep_state, data}
  end

  def connected(:info, {:tcp_error, socket, reason}, %__MODULE__{socket: socket} = data) do
    Logger.error("Connection error: #{:inet.format_error(reason)}")
    {:next_state, :disconnected, data}
  end

  def connected(:info, {:tcp_closed, socket}, %__MODULE__{socket: socket} = data) do
    Logger.error("Connection closed")
    {:next_state, :disconnected, data}
  end

  def connected(:info, {:tcp, socket, received_bytes}, %__MODULE__{socket: socket} = data) do
    :ok = :inet.setopts(data.socket, active: :once)
    {data, actions} = handle_new_bytes(data, received_bytes)
    {:keep_state, data, actions}
  end

  ## Helpers
  defp handle_new_bytes(data, bytes) do
    handle_new_bytes(data, bytes, _actions_acc = [])
  end

  defp handle_new_bytes(data, bytes, actions) do
    continuation = data.continuation || (&RESP.decode/1)

    case continuation.(bytes) do
      {:ok, response, rest} ->
        data = %__MODULE__{data | continuation: nil}
        {{:value, caller}, data} = get_and_update_in(data.queue, &:queue.out/1)
        actions = [{:reply, caller, {:ok, response}} | actions]
        handle_new_bytes(data, rest, actions)

      {:continuation, continuation} ->
        {%__MODULE__{data | continuation: continuation}, actions}
    end
  end
end
