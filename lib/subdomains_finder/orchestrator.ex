defmodule SubdomainsFinder.Orchestrator do
  require Logger

  @available_engines [
    SubdomainsFinder.Engines.Google,
    SubdomainsFinder.Engines.Netcraft,
    SubdomainsFinder.Engines.DNSDumpster,
    SubdomainsFinder.Engines.ThreatCrowd,
    SubdomainsFinder.Engines.CrtSearch
  ]

  def scan_domain(domain, opts \\ []) do
    with {:ok, domain} <- validate_domain(domain),
         {:ok, engines} <- get_engines(opts),
         {:ok, tasks} <- create_tasks(domain, engines, opts) do
      process_results(domain, tasks)
    end
  end

  defp validate_domain(domain) do
    SubdomainsFinder.Domain.validate(domain)
  end

  defp get_engines(opts) do
    engines = case Keyword.get(opts, :engines) do
      nil -> @available_engines
      engines_string ->
        engines_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&String.downcase/1)
        |> Enum.map(&engine_module/1)
        |> Enum.reject(&is_nil/1)
    end

    if Enum.empty?(engines) do
      {:error, "No valid engines specified"}
    else
      {:ok, engines}
    end
  end

  defp engine_module("google"), do: SubdomainsFinder.Engines.Google
  defp engine_module("netcraft"), do: SubdomainsFinder.Engines.Netcraft
  defp engine_module("dnsdumpster"), do: SubdomainsFinder.Engines.DNSDumpster
  defp engine_module("threatcrowd"), do: SubdomainsFinder.Engines.ThreatCrowd
  defp engine_module("ssl"), do: SubdomainsFinder.Engines.CrtSearch
  defp engine_module(_), do: nil

  defp create_tasks(domain, engines, opts) do
    tasks = Enum.map(engines, fn engine ->
      Task.async(fn ->
        try do
          case engine.enumerate(domain, opts) do
            {:ok, subdomains} -> 
              {engine.name(), {:ok, subdomains}}
            {:error, reason} -> 
              {engine.name(), {:error, reason}}
          end
        rescue
          e ->
            Logger.error("Engine #{engine.name()} failed: #{inspect(e)}")
            {engine.name(), {:error, :engine_failed}}
        end
      end)
    end)

    {:ok, tasks}
  end

  defp process_results(domain, tasks) do
    results = Task.await_many(tasks, 30_000)
    |> Enum.reduce(%{subdomains: MapSet.new(), errors: []}, fn {engine, result}, acc ->
      case result do
        {:ok, subdomains} ->
          %{acc | subdomains: MapSet.union(acc.subdomains, MapSet.new(subdomains))}
        {:error, reason} ->
          %{acc | errors: [{engine, reason} | acc.errors]}
      end
    end)

    subdomains = results.subdomains
    |> MapSet.to_list()
    |> Enum.sort()

    # Store results
    SubdomainsFinder.Store.add_results(domain, subdomains, %{
      engines_used: Enum.map(tasks, fn task -> task.pid end),
      errors: results.errors
    })

    if Enum.empty?(subdomains) and not Enum.empty?(results.errors) do
      {:error, "All engines failed: #{inspect(results.errors)}"}
    else
      {:ok, subdomains}
    end
  end
end
