defmodule Chat.AcceptorPool.TCPSupervisor do
  @moduledoc false
  use Supervisor

  def start_link(options) do
    Supervisor.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl Supervisor
  def init(options) do
    children = [
      {Chat.AcceptorPool.Listener, {options, self()}}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
