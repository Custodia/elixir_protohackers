defmodule PrimeTime.TcpServerTest do
  use ExUnit.Case

  test "answers multiple valid requests in a connection" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4010, mode: :binary, packet: :line, active: false)
    assert :gen_tcp.send(socket, Jason.encode!(%{ method: "isPrime", number: 7 }) <> "\n") == :ok
    assert_json_message_received(socket, %{ "method" => "isPrime", "prime" => true })
    assert :gen_tcp.send(socket, Jason.encode!(%{ method: "isPrime", number: 1.0 }) <> "\n") == :ok
    assert_json_message_received(socket, %{ "method" => "isPrime", "prime" => false })
    :gen_tcp.shutdown(socket, :write)
  end

  test "handles multiple lines of json objects in a single request" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4010, mode: :binary, packet: :line, active: false)

    request =
      [7, -1, 3.0, 17]
      |> Enum.map(fn n -> Jason.encode!(%{ method: "isPrime", number: n }) <> "\n" end)
      |> Enum.join("")
    assert :gen_tcp.send(socket, request) == :ok
    assert_json_message_received(socket, %{ "method" => "isPrime", "prime" => true })
    assert_json_message_received(socket, %{ "method" => "isPrime", "prime" => false })
    assert_json_message_received(socket, %{ "method" => "isPrime", "prime" => false })
    assert_json_message_received(socket, %{ "method" => "isPrime", "prime" => true })
    :gen_tcp.shutdown(socket, :write)
  end

  test "with an invalid request closes the socket after answering" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4010, mode: :binary, packet: :line, active: false)
    assert :gen_tcp.send(socket, Jason.encode!(%{ method: "isPrime", number: -13 }) <> "\n") == :ok
    assert_json_message_received(socket, %{ "method" => "isPrime", "prime" => false })
    assert :gen_tcp.send(socket, Jason.encode!(%{ method: "isPrime?", number: 1.0 }) <> "\n") == :ok
    assert_json_message_received(socket, %{ "error" => "malformed request" })
    assert :gen_tcp.recv(socket, _bytes_to_read = 0, _timeout_ms = 5_000) == {:error, :closed}
    assert :gen_tcp.send(socket, Jason.encode!(%{ method: "isPrime", number: -13 }) <> "\n") == {:error, :closed}
  end

  test "tcp server handles multiple connections at once" do
    tasks =
      for _ <- 1..100 do
        Task.async(fn ->
          {:ok, socket} = :gen_tcp.connect(~c"localhost", 4010, mode: :binary, packet: :line, active: false)
          assert :gen_tcp.send(socket, Jason.encode!(%{ method: "isPrime", number: 7 }) <> "\n") == :ok
          assert_json_message_received(socket, %{ "method" => "isPrime", "prime" => true })
          assert :gen_tcp.send(socket, Jason.encode!(%{ method: "isPrime", number: 1.0 }) <> "\n") == :ok
          assert_json_message_received(socket, %{ "method" => "isPrime", "prime" => false })
          :gen_tcp.shutdown(socket, :write)
        end)
      end

    Enum.each(tasks, &Task.await/1)
  end

  # Helpers

  defp assert_json_message_received(socket, expected) do
    {:ok, response} = :gen_tcp.recv(socket, _bytes_to_read = 0, _timeout_ms = 5_000)
    {:ok, result} = Jason.decode(response)
    assert result == expected
  end
end
