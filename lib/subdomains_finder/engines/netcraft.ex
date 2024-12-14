defmodule SubdomainsFinder.Engines.Netcraft do
  use SubdomainsFinder.Engine
  require Logger

  @base_url "https://searchdns.netcraft.com/?restriction=site+ends+with&host={domain}"

  @impl true
  def name, do: "netcraft"

  @impl true
  def enumerate(domain, opts \\ [])

  def enumerate(domain, opts) do
    client = setup_http_client()
    do_enumerate(domain, client, MapSet.new(), opts)
  end

  @impl true
  def handle_call({:enumerate, domain, opts}, _from, state) do
    case enumerate(domain, opts) do
      {:ok, subdomains} -> {:reply, {:ok, subdomains}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp setup_http_client do
    Req.new(
      base_url: "https://searchdns.netcraft.com",
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

  defp do_enumerate(domain, client, found_subdomains, opts) do
    # First request to get cookies
    case make_initial_request(client) do
      {:ok, cookies} ->
        url = String.replace(@base_url, "{domain}", domain)
        process_pages(url, client, cookies, found_subdomains)

      {:error, reason} ->
        Logger.error("Netcraft enumeration failed during initial request: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp make_initial_request(client) do
    case Req.get(client, url: "https://searchdns.netcraft.com") do
      {:ok, %{status: 200, headers: headers}} ->
        cookies = extract_cookies(headers)
        {:ok, create_cookies(cookies)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_pages(url, client, cookies, found_subdomains) do
    case make_request(client, url, cookies) do
      {:ok, body} ->
        new_subdomains = extract_subdomains(body)
        updated_subdomains = MapSet.union(found_subdomains, MapSet.new(new_subdomains))

        case get_next_page(body) do
          nil ->
            {:ok, MapSet.to_list(updated_subdomains)}

          next_url ->
            :timer.sleep(random_sleep())
            process_pages(next_url, client, cookies, updated_subdomains)
        end

      {:error, reason} ->
        if MapSet.size(found_subdomains) > 0 do
          {:ok, MapSet.to_list(found_subdomains)}
        else
          {:error, reason}
        end
    end
  end

  defp make_request(client, url, cookies) do
    case Req.get(client, url: url, cookies: cookies) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, response} ->
        Logger.error("Unexpected response from Netcraft: #{inspect(response)}")
        {:error, :unexpected_response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_cookies(headers) do
    case Enum.find(headers, fn {k, _v} -> String.downcase(k) == "set-cookie" end) do
      {_, cookie_string} -> cookie_string
      nil -> nil
    end
  end

  defp create_cookies(nil), do: %{}
  defp create_cookies(cookie_string) do
    [cookie | _] = String.split(cookie_string, ";")
    [key, value] = String.split(cookie, "=")
    
    %{
      key => value,
      "netcraft_js_verification_response" => generate_verification_response(value)
    }
  end

  defp generate_verification_response(cookie_value) do
    cookie_value
    |> URI.decode()
    |> (&:crypto.hash(:sha, &1)).()
    |> Base.encode16(case: :lower)
  end

  defp extract_subdomains(body) do
    {:ok, document} = Floki.parse_document(body)
    
    Floki.find(document, "a.results-table__host")
    |> Enum.map(fn {"a", _, [content]} -> 
      content
      |> String.trim()
      |> extract_domain()
    end)
    |> Enum.reject(&is_nil/1)
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

  defp get_next_page(body) do
    {:ok, document} = Floki.parse_document(body)
    
    case Floki.find(document, "a:fl-contains('Next Page')") do
      [{"a", [{"href", next_url} | _], _} | _] ->
        "https://searchdns.netcraft.com" <> next_url
      _ ->
        nil
    end
  end

  defp random_sleep do
    # Sleep between 1 and 2 seconds
    Enum.random(1000..2000)
  end
end
