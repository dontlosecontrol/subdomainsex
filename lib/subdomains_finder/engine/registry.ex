defmodule SubdomainsFinder.Engine.Registry do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def register_engine(name, module) do
    GenServer.call(__MODULE__, {:register, name, module})
  end

  def get_engine(name) do
    GenServer.call(__MODULE__, {:get, name})
  end

  def get_all_engines do
    GenServer.call(__MODULE__, :get_all)
  end

  @impl true
  def init(_opts) do
    {:ok, %{engines: %{}}}
  end

  @impl true
  def handle_call({:register, name, module}, _from, state) do
    {:reply, :ok, put_in(state.engines[name], module)}
  end

  def handle_call({:get, name}, _from, state) do
    {:reply, Map.get(state.engines, name), state}
  end

  def handle_call(:get_all, _from, state) do
    {:reply, state.engines, state}
  end
end
