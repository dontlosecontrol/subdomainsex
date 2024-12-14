defmodule SubdomainsFinder do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {SubdomainsFinder.Config, []},
      {SubdomainsFinder.Engine.Registry, []},
      {SubdomainsFinder.RateLimit.Supervisor, []},
      {SubdomainsFinder.Store, []},
      {Task.Supervisor, name: SubdomainsFinder.TaskSupervisor},
      # Start all engines
      SubdomainsFinder.Engines.Google,
      SubdomainsFinder.Engines.Netcraft,
      SubdomainsFinder.Engines.DNSDumpster,
      SubdomainsFinder.Engines.ThreatCrowd,
      SubdomainsFinder.Engines.CrtSearch
    ]

    opts = [strategy: :one_for_one, name: SubdomainsFinder.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Register engines after they're started
        register_default_engines()
        SubdomainsFinder.Telemetry.setup()
        {:ok, pid}
      error ->
        error
    end
  end

  defp register_default_engines do
    [
      {"google", SubdomainsFinder.Engines.Google},
      {"netcraft", SubdomainsFinder.Engines.Netcraft},
      {"dnsdumpster", SubdomainsFinder.Engines.DNSDumpster},
      {"threatcrowd", SubdomainsFinder.Engines.ThreatCrowd},
      {"ssl", SubdomainsFinder.Engines.CrtSearch}
    ]
    |> Enum.each(fn {name, module} -> 
      SubdomainsFinder.Engine.Registry.register_engine(name, module)
    end)
  end

  def scan_domain(domain, opts \\ []) do
    SubdomainsFinder.Orchestrator.scan_domain(domain, opts)
  end

  def register_engine(name, module) do
    SubdomainsFinder.Engine.Registry.register_engine(name, module)
  end

  def get_engine(name) do
    SubdomainsFinder.Engine.Registry.get_engine(name)
  end
end
