defmodule SillyGame.Router do
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  get "/websocket" do
    conn
    |> WebSockAdapter.upgrade(SillyGame.Server, [], timeout: 600_000)
    |> halt()
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
