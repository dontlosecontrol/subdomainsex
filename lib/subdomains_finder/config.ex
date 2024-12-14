defmodule SubdomainsFinder.Config do
  use GenServer
  require Logger

  @app :subdomains_finder

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get(key, default \\ nil) do
    GenServer.call(__MODULE__, {:get, key, default})
  end

  def set(key, value) do
    GenServer.call(__MODULE__, {:set, key, value})
  end

  def get_rate_limit(engine) do
    GenServer.call(__MODULE__, {:get_rate_limit, engine})
  end

  def set_rate_limit(engine, limit) do
    GenServer.call(__MODULE__, {:set_rate_limit, engine, limit})
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get, key, default}, _from, state) do
    value = Application.get_env(@app, key, default)
    {:reply, value, state}
  end

  def handle_call({:set, key, value}, _from, _state) do
    Application.put_env(@app, key, value)
    {:reply, :ok, %{}}
  end

  def handle_call({:get_rate_limit, engine}, _from, state) do
    limits = Application.get_env(@app, :rate_limits, %{})
    limit = Map.get(limits, engine) || 
            Map.get(limits, "default") ||
            1_000
    {:reply, limit, state}
  end

  def handle_call({:set_rate_limit, engine, limit}, _from, _state) do
    limits = Application.get_env(@app, :rate_limits, %{})
    new_limits = Map.put(limits, engine, limit)
    Application.put_env(@app, :rate_limits, new_limits)
    {:reply, :ok, %{}}
  end
end
