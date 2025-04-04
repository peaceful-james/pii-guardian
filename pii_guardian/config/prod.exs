import Config

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration
config :pii_guardian, PIIGuardian.Repo,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

# Configure SSL for production database
config :pii_guardian, PIIGuardian.Repo,
  ssl: true

# Configure Oban for production
config :pii_guardian, Oban,
  repo: PIIGuardian.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, slack: 10, notion: 10, pii_analysis: 5]
