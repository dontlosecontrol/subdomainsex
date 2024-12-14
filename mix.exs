defmodule SubdomainsFinder.MixProject do
  use Mix.Project

  def project do
    [
      app: :subdomains_finder,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: SubdomainsFinder.CLI],
      config_path: "config/config.exs",
      config_warning: false
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SubdomainsFinder, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.4.0"},
      {:jason, "~> 1.2"},
      {:dns, "~> 2.2"},
      {:floki, "~> 0.32.0"},
      {:telemetry, "~> 1.0"},
      {:csv, "~> 3.0"}
    ]
  end
end
