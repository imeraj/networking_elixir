defmodule Mix.Tasks.Play do
  @moduledoc false
  use Mix.Task

  def run(_args = []) do
    port = String.to_integer(System.get_env("SILLY_GAME_PORT") || "9393")
    {:ok, conn} = Mint.HTTP.connect(:http, "localhost", port)
    {:ok, conn, ref} = Mint.WebSocket.upgrade(:ws, conn, "/websocket", [])

    http_reply =
      receive do
        message -> message
      after
        1000 -> Mix.raise("No response from the server within 1s")
      end

    {:ok, conn,
     [
       {:status, ^ref, status},
       {:headers, ^ref, headers},
       {:done, ^ref}
     ]} =
      Mint.WebSocket.stream(conn, http_reply)

    {:ok, conn, websocket} = Mint.WebSocket.new(conn, ref, status, headers)

    receive_loop(conn, websocket, ref, spawn_prompt_task())
  end

  defp receive_loop(conn, websocket, ws_ref, %Task{ref: ref} = _prompt_task) do
    receive do
      {^ref, _message} ->
        {:ok, websocket, data} =
          Mint.WebSocket.encode(websocket, {:text, "pong"})

        {:ok, conn} = Mint.WebSocket.stream_request_body(conn, ws_ref, data)

        Process.demonitor(ref, [:flush])
        receive_loop(conn, websocket, ws_ref, spawn_prompt_task())

      message ->
        case Mint.WebSocket.stream(conn, message) do
          {:ok, conn, [{:data, ^ws_ref, data}]} ->
            {:ok, websocket, [{:text, text}]} = Mint.WebSocket.decode(websocket, data)

            handle_text(text)
            Process.demonitor(ref, [:flush])
            receive_loop(conn, websocket, ws_ref, spawn_prompt_task())

          {:error, _conn, reason, _responses} ->
            Mix.raise("WebSocket error: #{inspect(reason)}")

          :unknown ->
            Mix.raise("Unknown message")
        end
    end
  end

  defp handle_text("ping") do
    Mix.shell().info([:white, "PING! Press enter within 1s!"])
  end

  defp handle_text("expired") do
    Mix.shell().info([:red, "You were too slow."])
  end

  defp handle_text("early") do
    Mix.shell().info([:red, "You were too early, don't cheat."])
  end

  defp handle_text("won") do
    Mix.shell().info([:green, "You won!"])
    System.halt(0)
  end

  defp spawn_prompt_task do
    Task.async(fn -> Mix.shell().prompt("Ready> ") end)
  end
end
