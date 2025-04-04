import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/pii_guardian start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :pii_guardian, PiiGuardianWeb.Endpoint, server: true
end

config :pii_guardian, PiiGuardian.SlackBot,
  app_token: System.fetch_env!("PII_GUARDIAN_SLACK_APP_TOKEN"),
  bot_token: System.fetch_env!("PII_GUARDIAN_SLACK_BOT_TOKEN"),
  bot: PiiGuardian.SlackBot

if config_env() == :prod do
  import_config "runtime_prod.exs"
end
