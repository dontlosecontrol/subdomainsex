import Config

config :logger, :console,
  format: "[$level] $message\n",
  level: :warn

config :subdomains_finder,
  rate_limits: %{
    "google" => 0,        # No rate limiting in tests
    "netcraft" => 0,
    "dnsdumpster" => 0,
    "threatcrowd" => 0,
    "ssl" => 0
  }
