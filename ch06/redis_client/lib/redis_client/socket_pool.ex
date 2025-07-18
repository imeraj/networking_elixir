defmodule RedisClient.SocketPool do
  @moduledoc """
  Pooling of resources (sockets)
  """
  @behaviour NimblePool

  alias RedisClient.RESP

  def start_link(options) do
    NimblePool.start_link(worker: {__MODULE__, options}, pool_size: 5)
  end

  def command(pool, command) do
    NimblePool.checkout!(pool, :command, fn _from, socket ->
      with :ok <- :gen_tcp.send(socket, RESP.encode(command)),
           {:ok, data} <- receive_response(socket, &RESP.decode/1) do
        {{:ok, data}, {:ok, socket}}
      else
        {:error, reason} -> {{:error, reason}, {:error, reason}}
      end
    end)
  end

  @impl NimblePool
  def init_worker(options) do
    host = Keyword.fetch!(options, :host)
    port = Keyword.fetch!(options, :port)
    parent = self()

    connect_fun = fn ->
      case :gen_tcp.connect(host, port, [:binary, active: :once], 5000) do
        {:ok, socket} ->
          :ok = :gen_tcp.controlling_process(socket, parent)
          socket

        {:error, _reason} ->
          nil
      end
    end

    {:async, connect_fun, _pool_state = options}
  end

  @impl NimblePool
  def handle_info({:tcp_closed, socket}, socket) do
    {:remove, :closed}
  end

  def handle_info({:tcp_error, socket, reason}, socket) do
    {:remove, reason}
  end

  def handle_info(_other, socket) do
    {:ok, socket}
  end

  @impl NimblePool
  def handle_checkout(:command, _from, socket, pool_state) do
    :ok = :inet.setopts(socket, active: false)
    {:ok, _client_state = socket, _worker_state = socket, pool_state}
  end

  @impl NimblePool
  def handle_checkin({:ok, socket}, _from, socket, pool_state) do
    :ok = :inet.setopts(socket, active: :once)
    {:ok, socket, pool_state}
  end

  def handle_checkin({:error, reason}, _from, _worker_state, pool_state) do
    {:remove, reason, pool_state}
  end

  @impl NimblePool
  def terminate_worker(_reason, socket, pool_state) do
    :gen_tcp.close(socket)
    {:ok, pool_state}
  end

  defp receive_response(socket, continuation) do
    case :gen_tcp.recv(socket, 0, 5000) do
      {:ok, data} ->
        case continuation.(data) do
          {:ok, response, _rest = ""} ->
            {:ok, response}

          {:continuation, new_continuation} ->
            receive_response(socket, new_continuation)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
