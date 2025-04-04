defmodule PiiGuardianWeb.Router do
  use PiiGuardianWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Pipeline for verifying Notion webhook events
  pipeline :notion_webhook do
    plug :accepts, ["json"]
    plug PiiGuardianWeb.Plugs.NotionVerificationPlug
  end

  scope "/api", PiiGuardianWeb do
    pipe_through :api
  end

  # Webhook routes
  scope "/webhooks", PiiGuardianWeb do
    # Use the notion_webhook pipeline for Notion endpoints
    scope "/notion" do
      pipe_through :notion_webhook

      post "/", NotionController, :events
    end

    # Other webhook routes can use the regular API pipeline
    pipe_through :api
  end
end
