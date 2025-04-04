defmodule PIIGuardian.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Database repo
      PIIGuardian.Repo,
      
      # Pub/Sub system
      {Phoenix.PubSub, name: PIIGuardian.PubSub},
      
      # Phoenix endpoint
      PIIGuardianWeb.Endpoint,
      
      # Finch HTTP client
      {Finch, name: PIIGuardian.Finch},
      
      # Background job processor
      {Oban, Application.fetch_env!(:pii_guardian, Oban)},
      
      # Slack supervisor
      PIIGuardian.Slack.Supervisor,
      
      # Notion supervisor
      PIIGuardian.Notion.Supervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PIIGuardian.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
