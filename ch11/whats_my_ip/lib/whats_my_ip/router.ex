defmodule WhatsMyIP.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/myip" do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    response_body = JSON.encode!(%{ip: ip})

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> send_resp(200, response_body)
  end

  match _ do
    send_resp(conn, 404, JSON.encode!(%{error: "route not found"}))
  end
end
