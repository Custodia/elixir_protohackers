defmodule SmokeTest.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: SmokeTest.TcpServerTaskSupervisor, max_children: 100},
      SmokeTest.TcpServer
    ]

    opts = [strategy: :one_for_one, name: SmokeTest.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
