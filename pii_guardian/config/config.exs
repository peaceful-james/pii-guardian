import Config

config :pii_guardian,
  ecto_repos: [PIIGuardian.Repo]

# Configure the Phoenix endpoint
config :pii_guardian, PIIGuardianWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: PIIGuardianWeb.ErrorHTML, json: PIIGuardianWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PIIGuardian.PubSub,
  live_view: [signing_salt: "j4FLMHdG"]

config :pii_guardian, PIIGuardian.Repo,
  database: "pii_guardian_#{config_env()}",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

config :pii_guardian, PIIGuardian.Slack,
  bot_token: System.get_env("SLACK_BOT_TOKEN"),
  signing_secret: System.get_env("SLACK_SIGNING_SECRET"),
  watched_channels: System.get_env("SLACK_WATCHED_CHANNELS", "")
                    |> String.split(",", trim: true)

config :pii_guardian, PIIGuardian.Notion,
  api_key: System.get_env("NOTION_API_KEY"),
  watched_databases: System.get_env("NOTION_WATCHED_DATABASES", "")
                     |> String.split(",", trim: true),
  polling_interval: String.to_integer(System.get_env("NOTION_POLLING_INTERVAL", "60000"))

config :pii_guardian, PIIGuardian.PII.AIService,
  service: System.get_env("AI_SERVICE", "openai"),
  api_key: System.get_env("AI_SERVICE_API_KEY"),
  endpoint: System.get_env("AI_SERVICE_ENDPOINT")

config :pii_guardian, Oban,
  repo: PIIGuardian.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, slack: 5, notion: 5, pii_analysis: 3]

config :tesla, adapter: Tesla.Adapter.Finch

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
