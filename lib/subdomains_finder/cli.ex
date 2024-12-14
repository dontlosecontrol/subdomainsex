defmodule SubdomainsFinder.CLI do
  def main(args) do
    {opts, _} = OptionParser.parse!(args,
      strict: [
        domain: :string,
        output: :string,
        verbose: :boolean,
        engines: :string,
        ports: :string,
        no_color: :boolean
      ],
      aliases: [
        d: :domain,
        o: :output,
        v: :verbose,
        e: :engines,
        p: :ports,
        n: :no_color
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
    if opts[:output] do
      File.write!(opts[:output], Enum.join(results, "\n"))
      IO.puts("Results saved to #{opts[:output]}")
    else
      Enum.each(results, &IO.puts/1)
    end
  end
end
