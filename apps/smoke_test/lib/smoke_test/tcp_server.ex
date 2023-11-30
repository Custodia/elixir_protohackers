defmodule SmokeTest.TcpServer do
  @moduledoc """
  Documentation for `SmokeTest.TcpServer`.
  """
  use GenServer, restart: :permanent

  require Logger

  defstruct [:listen_socket, :supervisor]

  @port 4000

  def start_link([] = _opts) do
    GenServer.start_link(__MODULE__, :no_state)
  end

  @impl true
  def init(:no_state) do
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)

    listen_options = [
      mode: :binary,
      active: false,
      reuseaddr: true,
      exit_on_close: false,
      backlog: 100
    ]

    case :gen_tcp.listen(@port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Starting SmokeTest server on #{@port}")
        state = %__MODULE__{ listen_socket: listen_socket, supervisor: supervisor }
        {:ok, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept, %__MODULE__{} = state) do
    case :gen_tcp.accept(state.listen_socket) do
      {:ok, socket} ->
        Task.Supervisor.start_child(
          SmokeTest.TcpServerTaskSupervisor,
          fn -> handle_connection(socket) end
        )
        {:noreply, state, {:continue, :accept}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  ## Helpers

  defp handle_connection(socket) do
    case recv_until_closed(socket, _buffer = "", _buffered_size = 0) do
      {:ok, data} -> :gen_tcp.send(socket, data)
      {:error, reason} -> Logger.error("Failed to receive data: #{inspect(reason)}")
    end

    :gen_tcp.close(socket)
  end

  @buffer_limit _100_kb = 1024 * 100

  defp recv_until_closed(socket, buffer, buffered_size) do
    case :gen_tcp.recv(socket, _bytes_to_read = 0, _timeout_ms = 10_000) do
      {:ok, data} when buffered_size + byte_size(data) > @buffer_limit -> {:error, :buffer_overflow}
      {:ok, data} -> recv_until_closed(socket, [buffer, data], buffered_size + byte_size(data))
      {:error, :closed} -> {:ok, buffer}
      {:error, reason} -> {:error, reason}
    end
  end
end
