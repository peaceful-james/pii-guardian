import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :pii_guardian, PiiGuardian.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "pii_guardian_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :pii_guardian, PiiGuardianWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "0wE2VJva4iNv6essIAExP3qc5mpklMdWLWt4MzPNaTBssTm9SW2dCe1ZVn70AiE1",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
