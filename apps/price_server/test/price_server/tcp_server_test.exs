defmodule PriceServer.TcpServerTest do
  use ExUnit.Case

  test "Correctly handles example scenario" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4020, mode: :binary, active: false)
    send_example_hex(socket, "49 00 00 30 39 00 00 00 65") # I 12345 101
    send_example_hex(socket, "49 00 00 30 3a 00 00 00 66") # I 12346 102
    send_example_hex(socket, "49 00 00 30 3b 00 00 00 64") # I 12347 100
    send_example_hex(socket, "49 00 00 a0 00 00 00 00 05") # I 40960 5
    send_example_hex(socket, "51 00 00 30 00 00 00 40 00") # Q 12288 16384
    result = :gen_tcp.recv(socket, _bytes_to_read = 4, _timeout_ms = 5_000)
    assert {:ok, <<101::integer-signed-size(32)>>} = result
    :gen_tcp.close(socket)
  end

  test "invalid requests get an error response" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4020, mode: :binary, active: false)
    send_example_hex(socket, "49 00 00 30 39 00 00 00 65") # I 12345 101
    assert :gen_tcp.send(socket, "G" <> <<100::integer-signed-size(32), 200::integer-signed-size(32)>>) == :ok

    result = :gen_tcp.recv(socket, _bytes_to_read = 17, _timeout_ms = 5_000)
    assert {:ok, "malformed request"} = result

    :gen_tcp.close(socket)
  end

  test "handles negative values correctly" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4020, mode: :binary, active: false)
    for i <- 1..100 do
      insert_request(socket, _timestamp = i, _price = -10)
    end
    query_request(socket, _mintime = -10, _maxtime = 20)

    assert {:ok, <<-10::integer-signed-size(32)>>} = :gen_tcp.recv(socket, _bytes_to_read = 4, _timeout_ms = 5_000)
  end

  test "tcp server handles multiple connections at once" do
    tasks =
      for _ <- 1..100 do
        Task.async(fn ->
          {:ok, socket} = :gen_tcp.connect(~c"localhost", 4020, mode: :binary, active: false)
          send_example_hex(socket, "49 00 00 30 39 00 00 00 65") # I 12345 101
          send_example_hex(socket, "49 00 00 30 3a 00 00 00 66") # I 12346 102
          send_example_hex(socket, "49 00 00 30 3b 00 00 00 64") # I 12347 100
          send_example_hex(socket, "49 00 00 a0 00 00 00 00 05") # I 40960 5
          send_example_hex(socket, "51 00 00 30 00 00 00 40 00") # Q 12288 16384
          result = :gen_tcp.recv(socket, _bytes_to_read = 4, _timeout_ms = 5_000)
          assert {:ok, <<101::integer-signed-size(32)>>} = result
          :gen_tcp.close(socket)
        end)
      end

    Enum.each(tasks, &Task.await/1)
  end

  defp send_example_hex(socket, hex) do
    hex = String.replace(hex, " ", "")
    request = <<String.to_integer(hex, 16)::size(72)>>
    assert :gen_tcp.send(socket, request) == :ok
  end

  defp insert_request(socket, timestamp, price) do
    request = "I" <> <<timestamp::integer-signed-size(32), price::integer-signed-size(32)>>
    assert :gen_tcp.send(socket, request) == :ok
  end

  defp query_request(socket, mintime, maxtime) do
    request = "Q" <> <<mintime::integer-signed-size(32), maxtime::integer-signed-size(32)>>
    assert :gen_tcp.send(socket, request) == :ok
  end
end
