defmodule PrimeTime.TcpServer do
  @moduledoc """
  Documentation for `PrimeTime.TcpServer`.
  """
  use GenServer, restart: :permanent

  require Logger

  defstruct [:listen_socket]

  @port 4010

  def start_link([] = _opts) do
    GenServer.start_link(__MODULE__, :no_state)
  end

  @impl true
  def init(:no_state) do
    listen_options = [
      mode: :binary,
      packet: :line,
      buffer: 1024 * 100,
      active: false,
      reuseaddr: true,
      exit_on_close: false,
      backlog: 100
    ]

    case :gen_tcp.listen(@port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Starting PrimeTime server on #{@port}")
        state = %__MODULE__{ listen_socket: listen_socket }
        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    with {:ok, socket} <- :gen_tcp.accept(state.listen_socket),
         {:ok, task_pid} <- Task.Supervisor.start_child(
                              PrimeTime.TcpServerTaskSupervisor,
                              fn -> handle_connection(socket) end
                            ),
         _ <- :gen_tcp.controlling_process(socket, task_pid)
    do
      {:noreply, state, {:continue, :accept}}
    else
      {:error, reason} ->
        {:stop, reason}
    end
  end

  ## Helpers

  defp handle_connection(socket) do
    case recv_until_closed(socket) do
      {:error, :closed} -> :ok
      {:error, :malformed_request} -> :ok
      {:error, reason} -> Logger.error("Failed to receive data: #{inspect(reason)}")
    end

    :gen_tcp.close(socket)
  end

  defp recv_until_closed(socket) do
    with {:ok, data} <- :gen_tcp.recv(socket, _bytes_to_read = 0, _timeout_ms = 10_000),
         {:ok, parsed_data} <- Jason.decode(data),
         {:ok, number} <- parse_request(parsed_data)
      do
        result = PrimeTime.is_prime?(number)
        response = Jason.encode!(%{ method: "isPrime", prime: result }) <> "\n"
        :gen_tcp.send(socket, response)
        recv_until_closed(socket)
      else
        {:error, :closed} -> {:error, :closed}
        {:error, %Jason.DecodeError{}} ->
          response = Jason.encode!(%{ error: "malformed request" }) <> "\n"
          :gen_tcp.send(socket, response)
          {:error, :malformed_request}
        {:error, :malformed_request} ->
          response = Jason.encode!(%{ error: "malformed request" }) <> "\n"
          :gen_tcp.send(socket, response)
          {:error, :malformed_request}
        {:error, reason} -> {:error, reason}
    end
  end

  defp parse_request(%{ "method" => "isPrime", "number" => number }) when is_number(number), do: {:ok, number}
  defp parse_request(_), do: {:error, :malformed_request}
end
