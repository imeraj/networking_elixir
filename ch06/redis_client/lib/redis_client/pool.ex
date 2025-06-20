defmodule RedisClient.Pool do
  @moduledoc """
  Pooling of processes
  """

  def start_link(worker_args) do
    pool_args = [worker_module: RedisClientQueue, size: 5]
    :poolboy.start_link(pool_args, worker_args)
  end

  def command(pool, command) do
    :poolboy.transaction(pool, fn client ->
      RedisClientQueue.command(client, command)
    end)
  end
end
