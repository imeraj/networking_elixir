defmodule Xdig do
  @moduledoc """
  xdig DNS client
  """

  @spec lookup(:inet.ip_address(), :a, [String.t()]) :: [XDig.Protocol.Answer.t()]
  def lookup(server_address, record_type, hostname) do
    message_id = :crypto.strong_rand_bytes(2)
    encoded_dns_message = encode_dns_message(message_id, record_type, hostname)

    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])
    :gen_udp.send(socket, server_address, 53, encoded_dns_message)

    {:ok, {^server_address, 53, packet}} = :gen_udp.recv(socket, 0, 5000)

    :ok = :gen_udp.close(socket)

    decode_dns_message(message_id, packet)
  end

  defp encode_dns_message(message_id, record_type, hostname) do
    header = %XDig.Protocol.Header{
      message_id: message_id,
      qr: 0,
      opcode: 0,
      rcode: 0,
      qd_count: 1,
      an_count: 0,
      ns_count: 0,
      ar_count: 0,
      aa: 0,
      tc: 0,
      rd: 1,
      ra: 0
    }

    question = %XDig.Protocol.Question{
      qname: hostname,
      qtype: record_type,
      qclass: 1
    }

    [
      XDig.Protocol.encode_header(header),
      XDig.Protocol.encode_question(question)
    ]
  end

  defp decode_dns_message(message_id, <<header::12-binary, rest::binary>> = packet) do
    %XDig.Protocol.Header{
      message_id: ^message_id,
      qr: 1,
      opcode: 0,
      rcode: 0,
      qd_count: 1,
      an_count: answer_count
    } =
      XDig.Protocol.decode_header(header)

    {_question, rest} = XDig.Protocol.decode_question(rest)

    {answers, rest} =
      Enum.map_reduce(1..answer_count, rest, fn _index, rest ->
        XDig.Protocol.decode_answer(packet, rest)
      end)

    if rest != "", do: raise("unexpected trailing data in DNS message")

    answers
  end

  require Record

  for {record, fields} <-
        Record.extract_all(from_lib: "kernel/src/inet_dns.hrl") do
    Record.defrecord(record, fields)
  end
end
