defmodule SubdomainsFinder.Engine do
  @callback name() :: String.t()
  @callback do_enumerate(domain :: String.t(), opts :: keyword()) :: {:ok, [String.t()]} | {:error, term()}

  # Common functions that can be used by all engines
  def child_spec(module, opts) do
    %{
      id: module,
      start: {module, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  def start_engine(module, opts \\ []) do
    GenServer.start_link(module, opts, name: module)
  end

  def init_engine(module, opts) do
    rate_limit = SubdomainsFinder.Config.get_rate_limit(module.name())
    SubdomainsFinder.RateLimit.Worker.set_rate(module.name(), rate_limit)

    {:ok, %{
      opts: opts,
      rate_limit: rate_limit,
      user_agent: SubdomainsFinder.Config.get(:user_agent)
    }}
  end

  def enumerate(module, domain, opts \\ []) do
    GenServer.call(module, {:enumerate, domain, opts},
      SubdomainsFinder.Config.get([:timeouts, :engine]))
  end

  def handle_enumerate_call(module, {domain, opts}, _from, state) do
    case module.do_enumerate(domain, opts) do
      {:ok, subdomains} -> {:reply, {:ok, subdomains}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end
end
