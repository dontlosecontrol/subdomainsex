defmodule SubdomainsFinder do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {SubdomainsFinder.Config, []},
      {SubdomainsFinder.RateLimit.Supervisor, []},
      {SubdomainsFinder.Store, []},
      {SubdomainsFinder.Engine.Supervisor, []}
    ]

    opts = [strategy: :one_for_one, name: SubdomainsFinder.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def scan_domain(domain, opts \\ []) do
    SubdomainsFinder.Orchestrator.scan_domain(domain, opts)
  end
end
