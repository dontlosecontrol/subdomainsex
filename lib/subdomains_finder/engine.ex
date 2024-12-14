defmodule SubdomainsFinder.Engine do
  @callback name() :: String.t()
  @callback enumerate(domain :: String.t(), opts :: keyword()) :: {:ok, [String.t()]} | {:error, term()}
  
  defmacro __using__(_opts) do
    quote do
      @behaviour SubdomainsFinder.Engine
      use GenServer
      require Logger
      
      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end

      @impl true
      def init(opts) do
        {:ok, %{opts: opts}}
      end

      def enumerate(domain, opts \\ []) do
        GenServer.call(__MODULE__, {:enumerate, domain, opts})
      end

      defoverridable [init: 1]
    end
  end
end
