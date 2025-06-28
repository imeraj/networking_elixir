defmodule Chat.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      mod: application_mod()
    ]
  end

  defp application_mod do
    cond do
      System.get_env("POOL") ->
        {Chat.AcceptorPool.Application, []}

      System.get_env("THOUSAND_ISLAND") ->
        {Chat.ThousandIsland.Application, []}

      true ->
        {Chat.Application, []}
    end
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :wx, :observer, :ssl],
      mod: application_mod()
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:thousand_island, "~> 1.3"}
    ]
  end
end
