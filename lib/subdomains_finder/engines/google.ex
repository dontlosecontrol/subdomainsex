defmodule SubdomainsFinder.Engines.Google do
  @behaviour SubdomainsFinder.Engine
  use GenServer
  require Logger

  @base_url "https://google.com/search"
  @max_domains 11
  @max_pages 200

  # API
  def start_link(opts \\ []) do
    SubdomainsFinder.Engine.start_engine(__MODULE__, opts)
  end

  def enumerate(domain, opts \\ []) do
    GenServer.call(__MODULE__, {:enumerate, domain, opts})
  end

  # Callbacks
  @impl GenServer
  def init(opts) do
    SubdomainsFinder.Engine.init_engine(__MODULE__, opts)
  end

  @impl GenServer
  def handle_call({:enumerate, domain, opts}, _from, state) do
    client = setup_http_client()
    case do_enumerate_pages(domain, client, MapSet.new(), opts) do
      {:ok, subdomains} -> {:reply, {:ok, subdomains}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl SubdomainsFinder.Engine
  def name, do: "google"

  @impl SubdomainsFinder.Engine
  def do_enumerate(domain, opts) do
    client = setup_http_client()
    do_enumerate_pages(domain, client, MapSet.new(), opts)
  end

  defp do_enumerate_pages(domain, client, found_subdomains, opts, page_no \\ 0) do
    if check_max_pages(page_no) do
      {:ok, MapSet.to_list(found_subdomains)}
    else
      query = generate_query(domain, MapSet.to_list(found_subdomains))

      case make_request(client, query, page_no) do
        {:ok, body} ->
          new_subdomains = extract_subdomains(body, domain)
          updated_subdomains = MapSet.union(found_subdomains, MapSet.new(new_subdomains))

          if MapSet.size(updated_subdomains) == MapSet.size(found_subdomains) do
            {:ok, MapSet.to_list(updated_subdomains)}
          else
            :timer.sleep(5000) # Avoid rate limiting
            do_enumerate_pages(domain, client, updated_subdomains, opts, page_no + 10)
          end

        {:error, :rate_limited} ->
          Logger.warning("Rate limited by Google. Waiting 30 seconds before retry...")
          :timer.sleep(30_000)
          do_enumerate_pages(domain, client, found_subdomains, opts, page_no)

        {:error, reason} ->
          Logger.error("Google enumeration failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp setup_http_client do
    Req.new(
      base_url: @base_url,
      #user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
      user_agent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.5112.102 Safari/537.36",
      headers: [
        accept: "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "accept-language": "en-US,en;q=0.8",
        "accept-encoding": "gzip"
      ],
      retry: :transient,
      max_retries: 3,
      retry_delay: fn attempt -> attempt * 1000 end
    )
  end


  defp make_request(client, query, page_no) do
    params = [
      q: query,
      btnG: "Search",
      hl: "en-US",
      biw: "",
      bih: "",
      gbv: "1",
      start: to_string(page_no),
      filter: "0"
    ]

    case Req.get(client, params: params) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, response} ->
        Logger.error("Unexpected response: #{inspect(response)}")
        {:error, :unexpected_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_query(domain, []) do
    "site:#{domain} -www.#{domain}"
  end

  defp generate_query(domain, existing_subdomains) do
    excluded = existing_subdomains
    |> Enum.take(@max_domains - 2)
    |> Enum.map(&"-#{&1}")
    |> Enum.join(" ")

    "site:#{domain} -www.#{domain} #{excluded}"
  end

  defp extract_subdomains(body, domain) do
    {:ok, document} = Floki.parse_document(body)

    Floki.find(document, "cite")
    |> Enum.map(fn {"cite", _, [content]} ->
      content
      |> String.replace(~r/<.*?>/, "")
      |> extract_domain()
    end)
    |> Enum.filter(&valid_subdomain?(&1, domain))
  end

  defp extract_domain(url) do
    url = unless String.starts_with?(url, ["http://", "https://"]) do
      "http://" <> url
    else
      url
    end

    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> nil
    end
  end

  defp valid_subdomain?(nil, _domain), do: false
  defp valid_subdomain?(subdomain, domain) do
    String.ends_with?(subdomain, domain) and
    subdomain != domain and
    subdomain != "www." <> domain
  end

  defp check_max_pages(page_no) do
    page_no >= @max_pages
  end
end
