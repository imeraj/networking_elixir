defmodule Chat.ProtocolTest do
  use ExUnit.Case, async: true

  alias Chat.Messages.{Register, Broadcast}

  describe "encode_message/1" do
    test "can encode Register messages" do
      message = %Register{username: "meg"}
      iodata = Chat.Protocol.encode_message(message)

      assert IO.iodata_to_binary(iodata) == <<0x01, 0x00, 0x03, "meg">>
    end

    test "can encode Broadcast messages" do
      message = %Broadcast{from_username: "meg", contents: "hi"}
      iodata = Chat.Protocol.encode_message(message)

      assert IO.iodata_to_binary(iodata) == <<0x02, 0x00, 0x03, "meg", 0x00, 0x2, "hi">>
    end
  end

  describe "decode_message/1" do
    test "can decode register messages" do
      binary = <<0x01, 0x00, 0x03, "meg", "rest">>
      {:ok, message, rest} = Chat.Protocol.decode_message(binary)

      assert message == %Register{username: "meg"}
      assert rest == "rest"

      assert Chat.Protocol.decode_message(<<0x01, 0x00>>)
    end

    test "can decode brodcast messages" do
      binary = <<0x02, 3::16, "meg", 2::16, "hi", "rest">>
      {:ok, message, rest} = Chat.Protocol.decode_message(binary)

      assert message == %Broadcast{from_username: "meg", contents: "hi"}
      assert rest == "rest"

      assert Chat.Protocol.decode_message(<<0x02, 0x00>>) == :incomplete
    end

    test "return :incomplete for empty data" do
      assert Chat.Protocol.decode_message("") == :incomplete
    end

    test "returns :error for unknowne message types" do
      assert Chat.Protocol.decode_message(<<0x03, "rest">>) == :error
    end
  end
end
