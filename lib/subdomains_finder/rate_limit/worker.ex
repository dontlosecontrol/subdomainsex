defmodule SubdomainsFinder.RateLimit.Worker do
  use GenServer
  require Logger

  @default_rate 1_000 # 1 request per second
  @default_burst 10   # Allow burst of 10 requests

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def request(key, opts \\ []) do
    GenServer.call(__MODULE__, {:request, key, opts})
  end

  def get_rate(key) do
    GenServer.call(__MODULE__, {:get_rate, key})
  end

  def set_rate(key, rate) do
    GenServer.call(__MODULE__, {:set_rate, key, rate})
  end

  @impl true
  def init(_opts) do
    {:ok, %{
      buckets: %{},
      rates: %{},
      last_refill: %{}
    }}
  end

  @impl true
  def handle_call({:request, key, opts}, _from, state) do
    rate = Map.get(state.rates, key, @default_rate)
    burst = Keyword.get(opts, :burst, @default_burst)
    
    now = System.monotonic_time(:millisecond)
    bucket = get_bucket(state, key, now, rate, burst)

    cond do
      bucket >= 1 ->
        new_state = update_bucket(state, key, bucket - 1, now)
        {:reply, :ok, new_state}

      bucket < 1 ->
        wait_time = calculate_wait_time(rate)
        Logger.debug("Rate limited #{key}, waiting #{wait_time}ms")
        Process.sleep(wait_time)
        new_state = update_bucket(state, key, burst - 1, now + wait_time)
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:get_rate, key}, _from, state) do
    rate = Map.get(state.rates, key, @default_rate)
    {:reply, rate, state}
  end

  def handle_call({:set_rate, key, rate}, _from, state) do
    new_state = %{state | rates: Map.put(state.rates, key, rate)}
    {:reply, :ok, new_state}
  end

  defp get_bucket(state, key, now, rate, burst) do
    last_time = Map.get(state.last_refill, key, now)
    current_tokens = Map.get(state.buckets, key, burst)
    
    elapsed = now - last_time
    new_tokens = min(burst, current_tokens + (elapsed * rate / 1000))
    
    new_tokens
  end

  defp update_bucket(state, key, tokens, time) do
    %{state |
      buckets: Map.put(state.buckets, key, tokens),
      last_refill: Map.put(state.last_refill, key, time)
    }
  end

  defp calculate_wait_time(rate) do
    trunc(1000 / rate)
  end
end
