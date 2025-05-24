defmodule Chat.Protocol do
  @moduledoc false

  alias Chat.Messages.{Broadcast, Register}

  @type message() :: :Register.t() | Broadcast.t()

  @spec encode_message(message()) :: iodata()
  def encode_message(message)

  def encode_message(%Register{} = msg) do
    [0x01, encode_string(msg.username)]
  end

  def encode_message(%Broadcast{} = msg) do
    [0x02, encode_string(msg.from_username), encode_string(msg.contents)]
  end

  defp encode_string(str) do
    <<byte_size(str)::16, str::binary>>
  end

  @spec decode_message(binary()) :: {:ok, message(), binary()} | :error | :incomplete
  def decode_message(<<0x01, rest::binary>>), do: decode_register(rest)
  def decode_message(<<0x02, rest::binary>>), do: decode_broadcast(rest)
  def decode_message(<<>>), do: :incomplete
  def decode_message(<<_::binary>>), do: :error

  defp decode_register(<<username_len::16, username::size(username_len)-binary, rest::binary>>),
    do: {:ok, %Register{username: username}, rest}

  defp decode_register(<<_::binary>>), do: :incomplete

  defp decode_broadcast(
         <<username_len::16, username::size(username_len)-binary, contents_len::16,
           contents::size(contents_len)-binary, rest::binary>>
       ),
       do: {:ok, %Broadcast{from_username: username, contents: contents}, rest}

  defp decode_broadcast(<<_::binary>>), do: :incomplete
end
