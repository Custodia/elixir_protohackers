defmodule PriceServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: PriceServer.TcpServerTaskSupervisor, max_children: 100},
      PriceServer.TcpServer
    ]

    opts = [strategy: :one_for_one, name: PriceServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
