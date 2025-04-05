ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(PiiGuardian.Repo, :manual)

# Setup Mox for all tests
Mox.defmock(PiiGuardian.MockSlackApi, for: PiiGuardian.SlackApiBehaviour)
Mox.defmock(PiiGuardian.MockNotionApi, for: PiiGuardian.NotionApiBehaviour)

Mox.defmock(PiiGuardian.MockAnthropicPiiDetection,
  for: PiiGuardian.AnthropicPiiDetectionBehaviour
)

Mox.defmock(PiiGuardian.MockAnthropix, for: PiiGuardian.AnthropixBehaviour)
Mox.defmock(PiiGuardian.MockSlackbot, for: PiiGuardian.SlackbotBehaviour)

# Set the application environment to use mock modules in test
Application.put_env(:pii_guardian, :slack_api, PiiGuardian.MockSlackApi)
Application.put_env(:pii_guardian, :notion_api, PiiGuardian.MockNotionApi)
Application.put_env(:pii_guardian, :anthropix, PiiGuardian.MockAnthropix)
Application.put_env(:pii_guardian, :slackbot, PiiGuardian.MockSlackbot)

# Allow mocks to be called from any process
# Mox.allow(PiiGuardian.MockSlackApi, self(), :any)
# Mox.allow(PiiGuardian.MockNotionApi, self(), :any)
# Mox.allow(PiiGuardian.MockAnthropicPiiDetection, self(), :any)
