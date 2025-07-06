Mix.install([:mint])

defmodule WebSocketPlayground do
  @moduledoc false

  def await_response(conn, ref, response \\ %{}) do
    receive do
      message ->
        case Mint.HTTP.stream(conn, message) do
          {:ok, conn, responses} ->
            {conn, Enum.reduce(responses, response, &process_response(&2, ref, &1))}

          {:error, _conn, reason, _responses} ->
            raise reason
        end
    after
      5000 ->
        raise "not messages received for 5 seconds"
    end
  end

  defp process_response(response, ref, {:status, ref, status}) do
    Map.put(response, :status, status)
  end

  defp process_response(response, ref, {:headers, ref, headers}) do
    Map.put(response, :headers, headers)
  end

  defp process_response(response, ref, {:data, ref, body}) do
    Map.put(response, :body, body)
  end

  defp process_response(response, ref, {:done, ref}) do
    response
  end
end

{:ok, conn} = Mint.HTTP1.connect(:https, "echo.websocket.org", 443)

key = Base.encode64(:crypto.strong_rand_bytes(16))

headers = [
  {"Connection", "Upgrade"},
  {"Upgrade", "websocket"},
  {"Sec-WebSocket-Version", "13"},
  {"Sec-WebSocket-Key", key}
]

{:ok, conn, ref} = Mint.HTTP1.request(conn, "GET", "/", headers, _body = nil)

{_conn, response} = WebSocketPlayground.await_response(conn, ref)

{"sec-websocket-accept", hash} = List.keyfind(response.headers, "sec-websocket-accept", 0)

magic_uuid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
expected_hash = Base.encode64(:crypto.hash(:sha, key <> magic_uuid))

IO.puts("Response status: #{response.status}\n")

IO.puts(
  "Response headers: #{Enum.map_join(response.headers, "\n", fn {k, v} -> "#{k}: #{v}" end)}\n"
)

IO.puts("Response hash: #{hash}")
IO.puts("Expected hash: #{expected_hash}")
