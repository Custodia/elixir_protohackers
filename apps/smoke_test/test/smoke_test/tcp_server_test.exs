defmodule SmokeTest.TcpServerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  test "writes everything received back after client closes write socket" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4000, mode: :binary, active: false)
    assert :gen_tcp.send(socket, "foo") == :ok
    assert :gen_tcp.send(socket, "bar") == :ok
    :gen_tcp.shutdown(socket, :write)
    assert :gen_tcp.recv(socket, _bytes_to_read = 0, _timeout_ms = 5_000) == {:ok, "foobar"}
  end

  @tag capture_log: true
  test "tcp server closes connection if too much data is sent" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4000, mode: :binary, active: false)
    assert :gen_tcp.send(socket, :binary.copy("a", _101_kb = 1024 * 101)) == :ok
    assert :gen_tcp.recv(socket, 0) == {:error, :closed}
  end

  test "tcp server handles multiple connections at once" do
    tasks =
      for _ <- 1..100 do
        Task.async(fn ->
          {:ok, socket} = :gen_tcp.connect(~c"localhost", 4000, mode: :binary, active: false)
          assert :gen_tcp.send(socket, "foo") == :ok
          assert :gen_tcp.send(socket, "bar") == :ok
          :gen_tcp.shutdown(socket, :write)
          assert :gen_tcp.recv(socket, _bytes_to_read = 0, _timeout_ms = 5_000) == {:ok, "foobar"}
        end)
      end

    Enum.each(tasks, &Task.await/1)
  end
end
