defmodule PiiGuardianWeb.Router do
  use PiiGuardianWeb, :router

  # Pipeline for verifying Notion webhook events
  pipeline :notion_webhook do
    plug :accepts, ["json"]
    plug PiiGuardianWeb.Plugs.NotionVerificationPlug
  end

  # Webhook routes
  scope "/webhooks", PiiGuardianWeb do
    # Use the notion_webhook pipeline for Notion endpoints
    scope "/notion" do
      pipe_through :notion_webhook

      post "/", NotionController, :events
    end
  end
end
