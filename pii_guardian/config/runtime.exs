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

get_env_var =
  if config_env() == :test do
    fn _name -> "" end
  else
    &System.fetch_env!/1
  end

config :pii_guardian, PiiGuardian.Slackbot,
  app_token: get_env_var.("PII_GUARDIAN_SLACK_APP_TOKEN"),
  bot_token: get_env_var.("PII_GUARDIAN_SLACK_BOT_TOKEN"),
  bot: PiiGuardian.Slackbot

config :slack_elixir, admin_user_token: get_env_var.("PII_GUARDIAN_SLACK_ADMIN_USER_TOKEN")

config :pii_guardian, PiiGuardianWeb.Plugs.NotionVerificationPlug,
  verification_token: get_env_var.("PII_GUARDIAN_NOTION_VERIFICATION_TOKEN")

# Set the Notion token from environment variable
config :pii_guardian, :notion_token, System.get_env("PII_GUARDIAN_NOTION_API_TOKEN")

if config_env() == :prod do
  import_config "runtime_prod.exs"
end
