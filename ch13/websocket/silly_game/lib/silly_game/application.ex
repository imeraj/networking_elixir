defmodule SillyGame.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Bandit,
       plug: SillyGame.Router,
       scheme: :http,
       port: String.to_integer(System.get_env("SILLY_GAME_PORT", "9393"))}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SillyGame.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
