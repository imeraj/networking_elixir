defmodule TCPEchoServer.IntegrationTest do
  use ExUnit.Case

  test "sends back the received data" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4000, [:binary, active: false])
    assert :ok == :gen_tcp.send(socket, "Hello World\n")

    assert {:ok, data} = :gen_tcp.recv(socket, 0, 500)
    assert data == "Hello World\n"
  end

  test "handles fragmented data" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4000, [:binary, active: false])
    assert :ok == :gen_tcp.send(socket, "Hello")
    assert :ok == :gen_tcp.send(socket, " world\nand one more\n")

    assert {:ok, data} = :gen_tcp.recv(socket, 0, 500)
    assert data == "Hello world\nand one more\n"
  end

  test "handles multiple clients simultaneously" do
    tasks =
      for _ <- 1..5 do
        Task.async(fn ->
          {:ok, socket} = :gen_tcp.connect(~c"localhost", 4000, [:binary, active: false])
          assert :ok == :gen_tcp.send(socket, "Hello World\n")

          assert {:ok, data} = :gen_tcp.recv(socket, 0, 500)
          assert data == "Hello World\n"
        end)
      end

    Task.await_many(tasks)
  end
end
