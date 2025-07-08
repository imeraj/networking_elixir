defmodule SillyGame.MixProject do
  use Mix.Project

  def project do
    [
      app: :silly_game,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {SillyGame.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mint_web_socket, "~> 1.0"},
      {:bandit, "~> 1.7"},
      {:websock_adapter, "~> 0.5.8"}
    ]
  end
end
