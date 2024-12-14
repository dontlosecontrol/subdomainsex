defmodule SubdomainsFinder.Engines.ThreatCrowd do
  @behaviour SubdomainsFinder.Engine
  use GenServer
  require Logger

  def start_link(opts \\ []) do
    SubdomainsFinder.Engine.start_engine(__MODULE__, opts)
  end

  @base_url "https://www.threatcrowd.org/searchApi/v2/domain/report/?domain={domain}"

  @impl SubdomainsFinder.Engine
  def name, do: "threatcrowd"

  def enumerate(domain, opts \\ []) do
    GenServer.call(__MODULE__, {:enumerate, domain, opts})
  end

  @impl GenServer
  def init(opts) do
    SubdomainsFinder.Engine.init_engine(__MODULE__, opts)
  end

  @impl GenServer
  def handle_call({:enumerate, domain, opts}, _from, state) do
    client = setup_http_client()
    case do_enumerate(domain, client, opts) do
      {:ok, subdomains} -> {:reply, {:ok, subdomains}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl SubdomainsFinder.Engine
  def do_enumerate(domain, opts) do
    client = setup_http_client()
    do_enumerate(domain, client, opts)
  end

  defp setup_http_client do
    Req.new(
      base_url: "https://www.threatcrowd.org",
      user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
      headers: [
        accept: "application/json,*/*",
        "accept-language": "en-US,en;q=0.8",
        "accept-encoding": "gzip"
      ],
      retry: true,
      max_retries: 3,
      retry_delay: fn attempt -> :timer.sleep(1000 * attempt) end
    )
  end

  defp do_enumerate(domain, client, _opts) do
    url = String.replace(@base_url, "{domain}", domain)

    case make_request(client, url) do
      {:ok, body} ->
        subdomains = extract_subdomains(body, domain)
        {:ok, subdomains}

      {:error, reason} ->
        Logger.error("ThreatCrowd enumeration failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp make_request(client, url) do
    case Req.get(client, url: url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, response} ->
        Logger.error("Unexpected response from ThreatCrowd: #{inspect(response)}")
        {:error, :unexpected_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_subdomains(body, domain) do
    case Jason.decode(body) do
      {:ok, %{"subdomains" => subdomains}} when is_list(subdomains) ->
        subdomains
        |> Enum.filter(&valid_subdomain?(&1, domain))
        |> Enum.uniq()

      {:ok, _} ->
        []

      {:error, reason} ->
        Logger.error("Failed to parse ThreatCrowd response: #{inspect(reason)}")
        []
    end
  end

  defp valid_subdomain?(subdomain, domain) when is_binary(subdomain) do
    String.ends_with?(subdomain, domain) and
    subdomain != domain and
    subdomain != "www." <> domain
  end
  defp valid_subdomain?(_, _), do: false
end
