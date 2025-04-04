defmodule PiiGuardianWeb.Router do
  use PiiGuardianWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", PiiGuardianWeb do
    pipe_through :api
  end

  # Webhook routes
  scope "/webhooks", PiiGuardianWeb do
    pipe_through :api

    post "/notion", NotionController, :events
  end
end
