defmodule Protohackers.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        smoke_test: [
          applications: [smoke_test: :permanent]
        ],
        prime_time: [
          applications: [prime_time: :permanent]
        ],
        price_server: [
          applications: [price_server: :permanent]
        ]
      ]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    []
  end
end
