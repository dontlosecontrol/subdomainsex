defmodule SubdomainsFinder.Engines.DNSDumpster do
  @behaviour SubdomainsFinder.Engine
  use GenServer
  require Logger

  @base_url "https://dnsdumpster.com"

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
  def name, do: "dnsdumpster"

  @impl SubdomainsFinder.Engine
  def do_enumerate(domain, opts) do
    client = setup_http_client()
    do_enumerate(domain, client, opts)
  end

  defp setup_http_client do
    Req.new(
      base_url: @base_url,
      user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
      headers: [
        accept: "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "accept-language": "en-US,en;q=0.8",
        "accept-encoding": "gzip",
        referer: "https://dnsdumpster.com"
      ],
      retry: :transient,
      max_retries: 3,
      retry_delay: fn attempt -> attempt * 1000 end
    )
  end

  defp do_enumerate(domain, client, _opts) do
    with {:ok, initial_resp} <- make_initial_request(client),
         {:ok, token} <- extract_csrf_token(initial_resp),
         {:ok, cookies} <- extract_cookies(initial_resp),
         {:ok, resp} <- make_search_request(client, domain, token, cookies) do

      subdomains = extract_subdomains(resp, domain)
      {:ok, validate_subdomains(subdomains, domain)}
    else
      {:error, reason} ->
        Logger.error("DNSDumpster enumeration failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp make_initial_request(client) do
    case Req.get(client) do
      {:ok, %{status: 200} = resp} -> {:ok, resp}
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_csrf_token(response) do
    case Floki.parse_document(response.body) do
      {:ok, document} ->
        case Floki.find(document, "input[name='csrfmiddlewaretoken']") do
          [{"input", attrs, _}] ->
            token = attrs |> Enum.find(fn {k, _} -> k == "value" end) |> elem(1)
            {:ok, token}
          _ ->
            {:error, :csrf_token_not_found}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_cookies(%{headers: headers}) do
    case Enum.find(headers, fn {k, _v} -> String.downcase(k) == "set-cookie" end) do
      {_, cookie_string} -> {:ok, parse_cookies(cookie_string)}
      nil -> {:error, :no_cookies_found}
    end
  end

  defp parse_cookies(cookie_string) do
    cookie_string
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn cookie ->
      case String.split(cookie, "=", parts: 2) do
        [key, value] -> {key, value}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp make_search_request(client, domain, token, cookies) do
    headers = [
      {"referer", @base_url},
      {"x-csrftoken", token}
    ]

    params = [
      csrfmiddlewaretoken: token,
      targetip: domain
    ]

    case Req.post(client,
      url: @base_url,
      headers: headers,
      form: params,
      cookies: cookies
    ) do
      {:ok, %{status: 200} = resp} -> {:ok, resp}
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_subdomains(%{body: body}, _domain) do
    case Floki.parse_document(body) do
      {:ok, document} ->
        document
        |> Floki.find("table.table")
        |> extract_domains_from_tables()
      {:error, _} ->
        []
    end
  end

  defp extract_domains_from_tables(tables) do
    tables
    |> Enum.flat_map(fn {"table", _, rows} ->
      Floki.find(rows, "td")
      |> Enum.map(&Floki.text/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&String.contains?(&1, ["*", "www"]))
      |> Enum.reject(&(&1 == ""))
    end)
    |> Enum.uniq()
  end

  defp validate_subdomains(subdomains, domain) do
    subdomains
    |> Enum.filter(&String.ends_with?(&1, domain))
    |> Enum.reject(&(&1 == domain))
    |> Enum.reject(&(&1 == "www." <> domain))
    |> Enum.uniq()
  end
end
