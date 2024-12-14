defmodule SubdomainsFinder.HTTPClient do
  @callback get(url :: String.t(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
  @callback post(url :: String.t(), body :: term(), opts :: keyword()) :: {:ok, map()} | {:error, term()}

  defmodule Req do
    @behaviour SubdomainsFinder.HTTPClient
    require Logger

    def get(url, opts \\ []) do
      make_request(:get, url, opts)
    end

    def post(url, body, opts \\ []) do
      make_request(:post, url, [body: body] ++ opts)
    end

    defp make_request(method, url, opts) do
      start_time = System.monotonic_time()

      result = 
        :telemetry.span(
          [:subdomains_finder, :http, :request],
          %{method: method, url: url},
          fn ->
            case Req.request(method, url, opts) do
              {:ok, response} = success -> 
                {success, %{status: response.status}}
              error -> 
                {error, %{error: error}}
            end
          end
        )

      duration = System.monotonic_time() - start_time
      Logger.debug("HTTP request completed", 
        method: method,
        url: url,
        duration_ms: System.convert_time_unit(duration, :native, :millisecond)
      )

      result
    end
  end
end
