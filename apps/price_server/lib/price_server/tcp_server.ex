defmodule PriceServer.TcpServer do
  @moduledoc """
  Documentation for `PriceServer.TcpServer`.
  """
  use GenServer, restart: :permanent

  require Logger

  defstruct [:listen_socket]

  @port 4020

  def start_link([] = _opts) do
    GenServer.start_link(__MODULE__, :no_state)
  end

  @impl true
  def init(:no_state) do
    listen_options = [
      mode: :binary,
      active: false,
      reuseaddr: true,
      exit_on_close: false,
      backlog: 100
    ]

    case :gen_tcp.listen(@port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Starting PriceServer server on #{@port}")
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
                              PriceServer.TcpServerTaskSupervisor,
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

  defp recv_until_closed(socket, prices \\ []) do
    with {:ok, data} <- :gen_tcp.recv(socket, _bytes_to_read = 9, _timeout_ms = 10_000),
         {:ok, prices} <- handle_request(socket, prices, data)
      do
        recv_until_closed(socket, prices)
      else
        {:error, :closed} -> {:error, :closed}
        {:error, :malformed_request} ->
          :gen_tcp.send(socket, "malformed request")
          {:error, :malformed_request}
        {:error, reason} -> {:error, reason}
    end
  end

  defp handle_request(socket, prices, request)
  defp handle_request(socket, prices, "I" <> <<timestamp::integer-signed-size(32), price::integer-signed-size(32)>>) do
    {:ok, [{timestamp, price} | prices]}
  end
  defp handle_request(socket, prices, "Q" <> <<mintime::integer-signed-size(32), maxtime::integer-signed-size(32)>>) do
    matching_prices =
      prices
      |> Enum.filter(fn {time, price} -> time >= mintime && time <= maxtime end)
      |> Enum.map(&elem(&1, 1))
    mean =
      if Enum.count(matching_prices) > 0, do: div(Enum.sum(matching_prices), Enum.count(matching_prices)), else: 0

    response = <<mean::integer-signed-size(32)>>
    :gen_tcp.send(socket, response)
    {:ok, prices}
  end
  defp handle_request(_, _, _), do: {:error, :malformed_request}
end
