defmodule PIIGuardian.Slack.EventHandler do
  @moduledoc """
  Handles Slack events and dispatches them for processing.
  """
  use Slack
  require Logger

  alias PIIGuardian.Slack.MessageProcessor
  alias PIIGuardian.Config.SlackChannels
  alias PIIGuardian.PubSub

  @doc """
  Handles message events from Slack.
  """
  @impl true
  def handle_event(message = %{type: "message"}, slack, state) do
    # Check if it's in a watched channel
    channel_id = message.channel

    if message.subtype == nil && SlackChannels.watching?(channel_id) do
      Logger.debug("Received message in watched channel #{channel_id}")
      
      # Process the message in a separate task to avoid blocking
      Task.start(fn -> MessageProcessor.process_message(message, slack) end)
    end

    {:ok, state}
  end

  # Handle message changed events (edits)
  @impl true
  def handle_event(
        %{type: "message", subtype: "message_changed"} = event,
        slack,
        state
      ) do
    channel_id = event.channel
    
    if SlackChannels.watching?(channel_id) do
      Logger.debug("Message changed in watched channel #{channel_id}")
      
      # Process the edited message
      new_message = Map.put(event.message, "channel", channel_id)
      Task.start(fn -> MessageProcessor.process_message(new_message, slack) end)
    end

    {:ok, state}
  end

  # Handle thread replies
  @impl true
  def handle_event(
        %{type: "message", thread_ts: thread_ts} = message,
        slack,
        state
      ) when not is_nil(thread_ts) do
    channel_id = message.channel
    
    if SlackChannels.watching?(channel_id) do
      Logger.debug("Received thread reply in watched channel #{channel_id}")
      
      # Process the thread message
      Task.start(fn -> MessageProcessor.process_message(message, slack) end)
    end

    {:ok, state}
  end

  # Default handler for other events
  @impl true
  def handle_event(_message, _slack, state) do
    {:ok, state}
  end

  # Handle Slack connection opened
  @impl true
  def handle_connect(slack, state) do
    Logger.info("Connected to Slack as #{slack.me.name}")
    {:ok, state}
  end

  # Handle info messages
  @impl true
  def handle_info({:message, message, channel}, slack, state) do
    # Send the message to the channel
    send_message(message, channel, slack)
    {:ok, state}
  end

  # Catch-all for other info messages
  @impl true
  def handle_info(_message, _slack, state) do
    {:ok, state}
  end
end
