defmodule PIIGuardian.Slack.Supervisor do
  @moduledoc """
  Supervisor for Slack-related processes.
  """
  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Slack supervisor")

    children = [
      # Configuration manager for watched channels
      PIIGuardian.Config.SlackChannels,
      
      # Slack connector process
      PIIGuardian.Slack.Connector,
      
      # Event handler for Slack messages
      PIIGuardian.Slack.EventHandler
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
