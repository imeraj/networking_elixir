defmodule Chat.AcceptorPool.AcceptorSupervisor do
  @moduledoc false
  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(options) do
    Supervisor.start_link(__MODULE__, options)
  end

  @impl Supervisor
  def init(options) do
    pool_size = Keyword.get(options, :pool_size, 10)
    listen_socket = Keyword.fetch!(options, :listen_socket)

    children =
      for index <- 1..pool_size do
        spec = {Chat.AcceptorPool.Acceptor, listen_socket}
        Supervisor.child_spec(spec, id: "acceptor-#{index}")
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
