defmodule ProtocolTest do
  use ExUnit.Case, async: true

  alias Chat.Message.{Broadcast, Register}

  describe "decode_message/1" do
    test "can decode register message" do
      binary = <<0x01, 3::16, "meg", "rest">>
      assert {:ok, message, rest} = Chat.Protocol.decode_message(binary)
      assert message == %Register{username: "meg"}
      assert rest == "rest"

      assert Chat.Protocol.decode_message(<<0x01, 0x00>>) == :incomplete
    end

    test "can decode broadcast message" do
      binary = <<0x02, 3::16, "meg", 2::16, "hi", "rest">>
      assert {:ok, message, rest} = Chat.Protocol.decode_message(binary)
      assert message == %Broadcast{from_username: "meg", contents: "hi"}
      assert rest == "rest"

      assert Chat.Protocol.decode_message(<<0x02, 0x00>>) == :incomplete
    end

    test "returns :incomplete for empty data" do
      assert Chat.Protocol.decode_message(<<>>) == :incomplete
    end

    test "returns :error for unknown message types" do
      assert Chat.Protocol.decode_message(<<0x03, 0x00>>) == :error
    end
  end

  describe "encode_message/1" do
    test "can encode register message" do
      message = %Register{username: "meg"}
      iodata = Chat.Protocol.encode_message(message)

      assert IO.iodata_to_binary(iodata) == <<0x01, 0x00, 0x03, "meg">>
    end

    test "can encode broadcast message" do
      message = %Broadcast{from_username: "meg", contents: "hi"}
      iodata = Chat.Protocol.encode_message(message)

      assert IO.iodata_to_binary(iodata) == <<0x02, 0x00, 0x03, "meg", 0x00, 0x02, "hi">>
    end
  end
end