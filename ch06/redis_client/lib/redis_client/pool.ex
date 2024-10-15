defmodule RedisClient.Pool do
  @moduledoc false

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(args) do
    {name, worker_args} = Keyword.pop!(args, :name)

    pool_args = [
      name: {:local, name},
      worker_module: RedisClientQueue,
      size: 5
    ]

    :poolboy.child_spec(name, pool_args, worker_args)
  end

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(worker_args) do
    pool_args = [worker_module: RedisClientQueue, size: 5]
    :poolboy.start_link(pool_args, worker_args)
  end

  @spec command(:poolboy.pool(), [String.t()]) ::
          {:ok, String.t()} | {:error, any()}
  def command(pool, command) do
    :poolboy.transaction(pool, fn client ->
      RedisClientQueue.command(client, command)
    end)
  end
end
