defmodule SubdomainsFinder.Engines.CrtSearch do
  @behaviour SubdomainsFinder.Engine
  use GenServer
  require Logger

  @base_url "https://crt.sh/?q=%25.{domain}"

  # API
  def start_link(opts \\ []) do
    SubdomainsFinder.Engine.start_engine(__MODULE__, opts)
  end

  def enumerate(domain, opts \\ []) do
    SubdomainsFinder.Engine.enumerate(__MODULE__, domain, opts)
  end

  # Callbacks
  @impl GenServer
  def init(opts) do
    SubdomainsFinder.Engine.init_engine(__MODULE__, opts)
  end

  @impl GenServer
  def handle_call({:enumerate, domain, opts}, from, state) do
    SubdomainsFinder.Engine.handle_enumerate_call(__MODULE__, {domain, opts}, from, state)
  end

  @impl SubdomainsFinder.Engine
  def name, do: "ssl"

  @impl SubdomainsFinder.Engine
  def do_enumerate(domain, opts) do
    client = setup_http_client()
    do_enumerate(domain, client, opts)
  end

  defp setup_http_client do
    Req.new(
      base_url: "https://crt.sh",
      user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
      headers: [
        accept: "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
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
        Logger.error("CrtSearch enumeration failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp make_request(client, url) do
    case Req.get(client, url: url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, response} ->
        Logger.error("Unexpected response from CrtSearch: #{inspect(response)}")
        {:error, :unexpected_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_subdomains(body, domain) do
    {:ok, document} = Floki.parse_document(body)
    
    document
    |> Floki.find("td")
    |> Enum.map(&Floki.text/1)
    |> Enum.flat_map(&extract_domains_from_text(&1, domain))
    |> Enum.uniq()
    |> Enum.filter(&valid_subdomain?(&1, domain))
  end

  defp extract_domains_from_text(text, domain) do
    text
    |> String.split(~r/<BR>|\s+/, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(&clean_domain/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.filter(&String.ends_with?(&1, domain))
  end

  defp clean_domain(domain) do
    domain = if String.contains?(domain, "@") do
      [_, domain] = String.split(domain, "@")
      domain
    else
      domain
    end

    domain = unless String.starts_with?(domain, ["http://", "https://"]) do
      "http://" <> domain
    else
      domain
    end

    case URI.parse(domain) do
      %URI{host: host} when is_binary(host) -> host
      _ -> nil
    end
  end

  defp valid_subdomain?(subdomain, domain) when is_binary(subdomain) do
    String.ends_with?(subdomain, domain) and
    subdomain != domain and
    subdomain != "www." <> domain and
    not String.contains?(subdomain, "*")
  end
  defp valid_subdomain?(_, _), do: false
end
