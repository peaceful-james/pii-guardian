defmodule PIIGuardian.Notion.Supervisor do
  @moduledoc """
  Supervisor for Notion-related processes.
  """
  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Notion supervisor")

    children = [
      # Configuration manager for watched databases
      PIIGuardian.Config.NotionDatabases,
      
      # Notion connector process
      PIIGuardian.Notion.Connector,
      
      # Poller for database changes
      PIIGuardian.Notion.Poller
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
