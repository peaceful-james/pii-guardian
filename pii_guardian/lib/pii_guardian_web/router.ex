defmodule PIIGuardianWeb.Router do
  use Phoenix.Router, helpers: false

  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PIIGuardianWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PIIGuardianWeb do
    pipe_through :browser

    get "/", PageController, :home
    
    # Dashboard routes
    live "/dashboard", DashboardLive.Index, :index
    live "/config", ConfigLive.Index, :index
  end

  # Other scopes may use custom stacks.
  scope "/api", PIIGuardianWeb do
    pipe_through :api
    
    # Webhook for Slack events
    post "/slack/events", SlackController, :events
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:pii_guardian, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PIIGuardianWeb.Telemetry
    end
  end
end