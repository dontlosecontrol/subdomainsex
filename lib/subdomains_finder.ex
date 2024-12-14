defmodule SubdomainsFinder do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {SubdomainsFinder.Config, []},
      {SubdomainsFinder.Engine.Registry, []},
      {DynamicSupervisor, strategy: :one_for_one, name: SubdomainsFinder.EngineSupervisor},
      {SubdomainsFinder.RateLimit.Supervisor, []},
      {SubdomainsFinder.Store, []},
      {Task.Supervisor, name: SubdomainsFinder.TaskSupervisor}
    ]

    opts = [strategy: :one_for_one, name: SubdomainsFinder.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        SubdomainsFinder.Telemetry.setup()
        {:ok, pid}
      error ->
        error
    end
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
