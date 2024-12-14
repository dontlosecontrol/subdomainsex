defmodule SubdomainsFinder.CLI do
  def main(args) do
    {opts, _} = OptionParser.parse!(args,
      strict: [
        domain: :string,
        output: :string,
        verbose: :boolean,
        engines: :string,
        ports: :string,
        no_color: :boolean,
        format: :string,
        headers: :boolean
      ],
      aliases: [
        d: :domain,
        o: :output,
        v: :verbose,
        e: :engines,
        p: :ports,
        n: :no_color,
        f: :format,
        h: :headers
      ]
    )

    case validate_opts(opts) do
      {:ok, opts} ->
        handle_scan(opts)
      {:error, message} ->
        IO.puts(:stderr, "Error: #{message}")
        System.halt(1)
    end
  end

  defp validate_opts(opts) do
    cond do
      !opts[:domain] ->
        {:error, "Domain is required"}
      !valid_domain?(opts[:domain]) ->
        {:error, "Invalid domain format"}
      true ->
        {:ok, opts}
    end
  end

  defp valid_domain?(domain) do
    regex = ~r/^(http|https)?[a-zA-Z0-9]+([\-\.]{1}[a-zA-Z0-9]+)*\.[a-zA-Z]{2,}$/
    String.match?(domain, regex)
  end

  defp handle_scan(opts) do
    case SubdomainsFinder.scan_domain(opts[:domain], opts) do
      {:ok, results} ->
        handle_results(results, opts)
      {:error, reason} ->
        IO.puts(:stderr, "Error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp handle_results(results, opts) do
    format = opts[:format] || "text"
    format_opts = [include_headers: opts[:headers]]

    case SubdomainsFinder.Formatter.format(results, format, format_opts) do
      {:ok, formatted} ->
        if opts[:output] do
          File.write!(opts[:output], formatted)
          IO.puts("Results saved to #{opts[:output]}")
        else
          IO.puts(formatted)
        end
      {:error, reason} ->
        IO.puts(:stderr, "Error formatting results: #{reason}")
        System.halt(1)
    end
  end
end
