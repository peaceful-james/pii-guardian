# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :pii_guardian,
  ecto_repos: [PiiGuardian.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configures the endpoint
config :pii_guardian, PiiGuardianWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: PiiGuardianWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PiiGuardian.PubSub,
  live_view: [signing_salt: "q/o7rnZ/"]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, JSON

seven_days_s = 60 * 60 * 24 * 7

config :pii_guardian, Oban,
  repo: PiiGuardian.Repo,
  notifier: Oban.Notifiers.PG,
  queues: [
    slack: 3,
    notion: 3
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: seven_days_s},
    {Oban.Plugins.Lifeline, rescue_after: :timer.minutes(30)}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
