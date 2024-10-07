defmodule ChatTest do
  use ExUnit.Case, async: true

  import Chat.Protocol
  alias Chat.Message.Register

  test "server closes connection if client sends register message twice" do
    {:ok, client} = :gen_tcp.connect(~c"localhost", 4000, [:binary])
    encoded_message = encode_message(%Register{username: "jd"})
    :ok = :gen_tcp.send(client, encoded_message)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        :ok = :gen_tcp.send(client, encoded_message)
        assert_receive {:tcp_closed, ^client}, 500
      end)

    assert log =~ "Invalid Register message"
  end
end
