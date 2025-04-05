ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(PiiGuardian.Repo, :manual)

# Setup Mox for all tests
Mox.defmock(PiiGuardian.MockSlackApi, for: PiiGuardian.Mocks.SlackApiBehaviour)
Mox.defmock(PiiGuardian.MockNotionApi, for: PiiGuardian.Mocks.NotionApiBehaviour)

Mox.defmock(PiiGuardian.MockAnthropicPiiDetection,
  for: PiiGuardian.Mocks.AnthropicPiiDetectionBehaviour
)

Mox.defmock(PiiGuardian.MockAnthropix, for: PiiGuardian.Mocks.AnthropixBehaviour)

# Set the application environment to use mock modules in test
Application.put_env(:pii_guardian, :slack_api, PiiGuardian.MockSlackApi)
Application.put_env(:pii_guardian, :notion_api, PiiGuardian.MockNotionApi)
Application.put_env(:pii_guardian, :anthropix, PiiGuardian.MockAnthropix)

# Allow mocks to be called from any process
# Mox.allow(PiiGuardian.MockSlackApi, self(), :any)
# Mox.allow(PiiGuardian.MockNotionApi, self(), :any)
# Mox.allow(PiiGuardian.MockAnthropicPiiDetection, self(), :any)
