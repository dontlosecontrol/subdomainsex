defmodule SubdomainsFinder.Store do
  use GenServer
  require Logger

  @type t :: %__MODULE__{
    results: %{String.t() => result()},
    metadata: %{String.t() => map()}
  }

  @type result :: %{
    subdomains: MapSet.t(),
    timestamp: DateTime.t(),
    status: :in_progress | :complete | :error,
    error: term() | nil
  }

  defstruct results: %{}, metadata: %{}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def add_results(domain, subdomains, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:add_results, domain, subdomains, metadata})
  end

  def get_results(domain) do
    GenServer.call(__MODULE__, {:get_results, domain})
  end

  def get_all_results do
    GenServer.call(__MODULE__, :get_all_results)
  end

  def mark_complete(domain) do
    GenServer.cast(__MODULE__, {:mark_status, domain, :complete})
  end

  def mark_error(domain, error) do
    GenServer.cast(__MODULE__, {:mark_error, domain, error})
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_cast({:add_results, domain, subdomains, metadata}, state) do
    result = Map.get(state.results, domain, new_result())
    updated_result = %{result | 
      subdomains: MapSet.union(result.subdomains, MapSet.new(subdomains)),
      timestamp: DateTime.utc_now()
    }
    
    new_state = %{state |
      results: Map.put(state.results, domain, updated_result),
      metadata: Map.update(
        state.metadata,
        domain,
        metadata,
        &Map.merge(&1, metadata)
      )
    }

    {:noreply, new_state}
  end

  def handle_cast({:mark_status, domain, status}, state) do
    new_state = update_in(
      state.results,
      [Access.key(domain, new_result())],
      &(%{&1 | status: status})
    )
    {:noreply, new_state}
  end

  def handle_cast({:mark_error, domain, error}, state) do
    new_state = update_in(
      state.results,
      [Access.key(domain, new_result())],
      &(%{&1 | status: :error, error: error})
    )
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_results, domain}, _from, state) do
    case Map.get(state.results, domain) do
      nil -> 
        {:reply, {:error, :not_found}, state}
      result -> 
        {:reply, {:ok, format_result(result)}, state}
    end
  end

  def handle_call(:get_all_results, _from, state) do
    results = state.results
    |> Enum.map(fn {domain, result} -> {domain, format_result(result)} end)
    |> Enum.into(%{})
    
    {:reply, results, state}
  end

  defp new_result do
    %{
      subdomains: MapSet.new(),
      timestamp: DateTime.utc_now(),
      status: :in_progress,
      error: nil
    }
  end

  defp format_result(result) do
    %{
      subdomains: MapSet.to_list(result.subdomains),
      timestamp: result.timestamp,
      status: result.status,
      error: result.error
    }
  end
end
