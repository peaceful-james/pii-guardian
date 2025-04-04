import Config

# Configure the database
config :pii_guardian, PIIGuardian.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "pii_guardian_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Configure Oban for testing
config :pii_guardian, Oban, testing: :inline

# Print only warnings and errors during test
config :logger, level: :warning

# Configure test-specific settings
config :pii_guardian, PIIGuardian.Slack,
  bot_token: "xoxb-test-token",
  signing_secret: "test-signing-secret",
  watched_channels: ["C01TEST123", "C02TEST456"]

config :pii_guardian, PIIGuardian.Notion,
  api_key: "test-api-key",
  watched_databases: ["db1-test-id", "db2-test-id"],
  polling_interval: 1000

config :pii_guardian, PIIGuardian.PII.AIService,
  service: "test",
  api_key: "test-api-key",
  endpoint: "http://localhost:4000/api/test"
