defmodule PIIGuardian.Slack.Actions do
  @moduledoc """
  Functions for performing actions on Slack, such as deleting messages
  and sending notifications.
  """
  require Logger

  alias PIIGuardian.Slack.Connector

  @doc """
  Deletes a message from a Slack channel.
  
  ## Parameters
    - channel_id: The ID of the channel containing the message
    - ts: The timestamp of the message to delete
  """
  def delete_message(channel_id, ts) do
    Logger.info("Deleting message in channel #{channel_id} with timestamp #{ts}")
    
    client = Connector.get_client()
    
    case Slack.Web.Chat.delete(channel_id, ts, %{as_user: true}, client) do
      %{"ok" => true} -> 
        Logger.info("Successfully deleted message")
        :ok
      error -> 
        Logger.error("Failed to delete message: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Notifies a user about PII found in their message.
  
  ## Parameters
    - user_id: The Slack user ID to notify
    - message_text: The message to send
    - pii_details: Details about the PII that was found (optional)
  """
  def notify_user(user_id, message_text, pii_details \\ nil) do
    Logger.info("Notifying user #{user_id} about PII")
    
    client = Connector.get_client()
    
    # Open a DM channel with the user
    case Slack.Web.Im.open(user_id, client) do
      %{"ok" => true, "channel" => %{"id" => dm_channel_id}} ->
        # Send the notification message
        notification = build_notification(message_text, pii_details)
        
        case Slack.Web.Chat.post_message(dm_channel_id, notification, %{as_user: true}, client) do
          %{"ok" => true} -> 
            Logger.info("Successfully sent notification to user #{user_id}")
            :ok
          error -> 
            Logger.error("Failed to send notification: #{inspect(error)}")
            {:error, error}
        end
        
      error ->
        Logger.error("Failed to open DM channel: #{inspect(error)}")
        {:error, error}
    end
  end

  # Private functions

  defp build_notification(message_text, nil) do
    message_text
  end

  defp build_notification(message_text, pii_details) do
    """
    #{message_text}
    
    PII types detected: #{format_pii_types(pii_details)}
    """
  end

  defp format_pii_types(pii_details) do
    pii_details.types
    |> Enum.map(&"*#{&1}*")
    |> Enum.join(", ")
  end
end
