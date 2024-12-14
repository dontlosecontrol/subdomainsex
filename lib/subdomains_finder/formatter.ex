defmodule SubdomainsFinder.Formatter do
  def format(results, format, opts \\ []) do
    case format do
      "json" -> format_json(results, opts)
      "csv" -> format_csv(results, opts)
      "text" -> format_text(results, opts)
      _ -> {:error, "Unsupported format: #{format}"}
    end
  end

  defp format_json(results, _opts) do
    {:ok, Jason.encode!(results, pretty: true)}
  end

  defp format_csv(results, opts) do
    headers = if opts[:include_headers], do: ["subdomain\n"], else: []
    rows = Enum.map(results, &(&1 <> "\n"))
    {:ok, Enum.join(headers ++ rows)}
  end

  defp format_text(results, _opts) do
    {:ok, Enum.join(results, "\n")}
  end
end
