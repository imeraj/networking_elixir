defmodule IntegrationTest do
  use ExUnit.Case, async: true

  alias Xstats.DaemonServer
  alias Xstats.Reporter

  @port 9324

  setup do
    {:ok, string_io} = StringIO.open("")

    {:ok, daemon} = start_supervised({DaemonServer, port: @port, flush_io_device: string_io})
    {:ok, reporter} = start_supervised({Reporter, port: @port})

    [daemon: daemon, reporter: reporter, string_io: string_io]
  end

  test "reporting a counter metric", ctx do
    %{daemon: daemon, reporter: reporter, string_io: string_io} = ctx

    assert :ok = Reporter.increment_counter(reporter, "reqs", 1)
    assert :ok = Reporter.increment_counter(reporter, "reqs", 4)

    until_assert_passes(fn ->
      assert DaemonServer.fetch_value(DaemonServer, "reqs") == {:ok, 5}
    end)

    send_and_flush_state(daemon)
    assert StringIO.flush(string_io) =~ "reqs:\t5\n"
  end

  test "reporting a gauge metric", ctx do
    %{daemon: daemon, reporter: reporter, string_io: string_io} = ctx
    assert :ok = Reporter.set_gauge(reporter, "dur", 103)

    until_assert_passes(fn ->
      assert DaemonServer.fetch_value(daemon, "dur") == {:ok, 103}
    end)

    assert :ok = Reporter.set_gauge(reporter, "dur", 949)

    until_assert_passes(fn ->
      assert DaemonServer.fetch_value(daemon, "dur") == {:ok, 949}
    end)

    send_and_flush_state(daemon)
    assert StringIO.flush(string_io) =~ "dur:\t949\n"

    # Gauge is not reset.
    assert DaemonServer.fetch_value(daemon, "dur") == {:ok, 949}
  end

  test "reporting multiple (good and bad) metrics in one packet", ctx do
    %{daemon: daemon} = ctx

    {:ok, socket} = :gen_udp.open(0, [:binary])

    packet = [
      Xstats.Protocol.encode_metric({:gauge, "mem_used_mb", 49.2}),
      Xstats.Protocol.encode_metric({:counter, "hits", 1}),
      Xstats.Protocol.encode_metric({:counter, "hits", 2}),
      "invalid line\n",
      Xstats.Protocol.encode_metric({:gauge, "mem_used_mb", 37.0})
    ]

    assert :ok = :gen_udp.send(socket, ~c"localhost", @port, packet)

    until_assert_passes(fn ->
      assert DaemonServer.fetch_value(daemon, "mem_used_mb") == {:ok, 37.0}
      assert DaemonServer.fetch_value(daemon, "hits") == {:ok, 3}
    end)
  end

  defp send_and_flush_state(pid) do
    send(pid, :flush)
    :sys.get_state(pid)
    :ok
  end

  defp until_assert_passes(fun, timeout \\ 500)

  defp until_assert_passes(fun, timeout) when timeout < 0 do
    fun.()
  end

  defp until_assert_passes(fun, timeout) do
    fun.()
  rescue
    ExUnit.AssertionError ->
      Process.sleep(10)
      until_assert_passes(fun, timeout - 10)
  end
end
