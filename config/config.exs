import Config

config :subdomains_finder,
  rate_limits: %{
    "google" => 1_000,      # 1 request per second
    "netcraft" => 2_000,    # 1 request per 2 seconds
    "dnsdumpster" => 5_000, # 1 request per 5 seconds
    "threatcrowd" => 2_000, # 1 request per 2 seconds
    "ssl" => 1_000         # 1 request per second
  },
  request_timeout: 30_000,  # 30 seconds
  engine_timeout: 60_000,   # 1 minute
  retries: %{
    max_attempts: 3,
    backoff: 1_000         # 1 second
  },
  user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

import_config "#{config_env()}.exs"
