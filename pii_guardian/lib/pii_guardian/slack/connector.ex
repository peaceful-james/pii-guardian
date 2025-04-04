defmodule PIIGuardian.Slack.Connector do
  @moduledoc """
  Handles Slack API authentication and real-time messaging.
  """
  use GenServer
  require Logger

  alias PIIGuardian.PubSub

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the Slack client state.
  """
  def get_client do
    GenServer.call(__MODULE__, :get_client)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Initializing Slack connector")
    
    bot_token = Application.get_env(:pii_guardian, PIIGuardian.Slack)[:bot_token]
    
    if bot_token do
      # Initialize the Slack client
      {:ok, client} = Slack.Bot.start_link(PIIGuardian.Slack.EventHandler, [], bot_token)
      
      Logger.info("Slack connector initialized successfully")
      {:ok, %{client: client}}
    else
      Logger.error("Slack bot token not configured")
      {:ok, %{client: nil}}
    end
  end

  @impl true
  def handle_call(:get_client, _from, state) do
    {:reply, state.client, state}
  end

  @impl true
  def handle_info({:slack_event, event}, state) do
    # Broadcast the event to subscribers
    PubSub.broadcast("slack:events", {:slack_event, event})
    {:noreply, state}
  end

  @impl true
  def handle_info(_, state), do: {:noreply, state}
end
