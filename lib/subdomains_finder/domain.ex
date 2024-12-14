defmodule SubdomainsFinder.Domain do
  @moduledoc """
  Domain validation and processing functionality.
  """

  @type t :: %__MODULE__{
    name: String.t(),
    subdomains: MapSet.t(),
    metadata: map()
  }

  defstruct [:name, subdomains: MapSet.new(), metadata: %{}]

  @doc """
  Validates and normalizes a domain name.
  """
  @spec validate(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate(domain) when is_binary(domain) do
    domain = String.trim(domain)
    cond do
      domain == "" ->
        {:error, "Domain cannot be empty"}
      
      String.contains?(domain, " ") ->
        {:error, "Domain cannot contain spaces"}
      
      String.contains?(domain, ["*", "?"]) ->
        {:error, "Domain cannot contain wildcards"}
      
      valid_format?(domain) ->
        {:ok, normalize_domain(domain)}
      
      true ->
        {:error, "Invalid domain format"}
    end
  end
  def validate(_), do: {:error, "Domain must be a string"}

  @doc """
  Checks if a subdomain belongs to the given domain.
  """
  @spec valid_subdomain?(String.t(), String.t()) :: boolean()
  def valid_subdomain?(subdomain, domain) when is_binary(subdomain) and is_binary(domain) do
    String.ends_with?(subdomain, domain) and
    subdomain != domain and
    subdomain != "www." <> domain and
    not String.contains?(subdomain, "*") and
    valid_format?(subdomain)
  end
  def valid_subdomain?(_, _), do: false

  @doc """
  Extracts domain from URL or email address.
  """
  @spec extract_domain(String.t()) :: String.t() | nil
  def extract_domain(url) when is_binary(url) do
    url = cond do
      String.contains?(url, "@") ->
        [_, domain] = String.split(url, "@")
        domain
      
      String.starts_with?(url, ["http://", "https://"]) ->
        url
      
      true ->
        "http://" <> url
    end

    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> nil
    end
  end
  def extract_domain(_), do: nil

  @doc """
  Creates a new domain struct.
  """
  @spec new(String.t(), [String.t()], map()) :: {:ok, t()} | {:error, String.t()}
  def new(domain, subdomains \\ [], metadata \\ %{}) do
    with {:ok, domain} <- validate(domain),
         clean_subdomains <- clean_and_validate_subdomains(subdomains, domain) do
      {:ok, %__MODULE__{
        name: domain,
        subdomains: MapSet.new(clean_subdomains),
        metadata: metadata
      }}
    end
  end

  # Private functions

  defp valid_format?(domain) do
    regex = ~r/^(http|https)?[a-zA-Z0-9]+([\-\.]{1}[a-zA-Z0-9]+)*\.[a-zA-Z]{2,}$/
    String.match?(domain, regex)
  end

  defp normalize_domain(domain) do
    domain
    |> String.downcase()
    |> String.trim()
    |> extract_domain()
    |> case do
      nil -> domain
      extracted -> extracted
    end
  end

  defp clean_and_validate_subdomains(subdomains, domain) do
    subdomains
    |> Enum.map(&normalize_domain/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&valid_subdomain?(&1, domain))
    |> Enum.uniq()
  end
end
