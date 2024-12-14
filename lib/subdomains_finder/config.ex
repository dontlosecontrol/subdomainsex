defmodule SubdomainsFinder.Config do
  use GenServer
  require Logger

  @default_config %{
    rate_limits: %{
      "google" => 1_000,      # 1 request per second
      "netcraft" => 2_000,    # 1 request per 2 seconds
      "dnsdumpster" => 5_000, # 1 request per 5 seconds
      "threatcrowd" => 2_000, # 1 request per 2 seconds
      "ssl" => 1_000         # 1 request per second
    },
    timeouts: %{
      request: 30_000,        # 30 seconds
      engine: 60_000         # 1 minute
    },
    retries: %{
      max_attempts: 3,
      backoff: 1_000         # 1 second
    },
    user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
  }

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
    {:ok, @default_config}
  end

  @impl true
  def handle_call({:get, key, default}, _from, state) do
    value = get_in(state, List.wrap(key)) || default
    {:reply, value, state}
  end

  def handle_call({:set, key, value}, _from, state) do
    new_state = put_in(state, List.wrap(key), value)
    {:reply, :ok, new_state}
  end

  def handle_call({:get_rate_limit, engine}, _from, state) do
    limit = get_in(state, [:rate_limits, engine]) ||
            get_in(state, [:rate_limits, "default"]) ||
            1_000
    {:reply, limit, state}
  end

  def handle_call({:set_rate_limit, engine, limit}, _from, state) do
    new_state = put_in(state, [:rate_limits, engine], limit)
    {:reply, :ok, new_state}
  end
end
