defmodule SubdomainsFinder.Telemetry do
  require Logger

  def setup do
    events = [
      [:subdomains_finder, :engine, :start],
      [:subdomains_finder, :engine, :stop],
      [:subdomains_finder, :engine, :error],
      [:subdomains_finder, :http, :request],
      [:subdomains_finder, :rate_limit, :throttle]
    ]

    :telemetry.attach_many(
      "subdomains-finder-metrics",
      events,
      &handle_event/4,
      nil
    )
  end

  def handle_event([:subdomains_finder, :engine, :start], measurements, metadata, _config) do
    Logger.info("Engine started", engine: metadata.engine, measurements: measurements)
  end

  def handle_event([:subdomains_finder, :engine, :stop], measurements, metadata, _config) do
    Logger.info("Engine stopped", 
      engine: metadata.engine, 
      duration: measurements.duration,
      subdomains: length(metadata.subdomains)
    )
  end

  def handle_event([:subdomains_finder, :engine, :error], _measurements, metadata, _config) do
    Logger.error("Engine error", 
      engine: metadata.engine,
      error: metadata.error
    )
  end

  def handle_event([:subdomains_finder, :http, :request], measurements, metadata, _config) do
    Logger.debug("HTTP request", 
      url: metadata.url,
      method: metadata.method,
      duration: measurements.duration
    )
  end

  def handle_event([:subdomains_finder, :rate_limit, :throttle], measurements, metadata, _config) do
    Logger.debug("Rate limit throttle", 
      key: metadata.key,
      wait_time: measurements.wait_time
    )
  end
end
