defmodule PIIGuardian.Slack.MessageProcessor do
  @moduledoc """
  Processes Slack messages for PII content.
  """
  require Logger

  alias PIIGuardian.PII.Analyzer
  alias PIIGuardian.Slack.Actions
  alias PIIGuardian.PubSub

  @doc """
  Processes a Slack message, checking for PII.
  
  If PII is found, the message is deleted and the user is notified.
  """
  def process_message(message, slack) do
    Logger.debug("Processing message: #{inspect(message)}")
    
    # Get message content and metadata
    content = extract_content(message)
    user_id = message.user
    channel_id = message.channel
    ts = message.ts
    
    # Check for PII in the content
    case Analyzer.analyze_content(content) do
      {:pii_found, pii_details} ->
        # PII was found, delete the message and notify user
        Logger.info("PII found in Slack message from user #{user_id} in channel #{channel_id}")
        
        # Delete the message
        Actions.delete_message(channel_id, ts)
        
        # Notify the user
        message_text = format_message_for_notification(message)
        Actions.notify_user(user_id, message_text, pii_details)
        
        # Broadcast event
        PubSub.broadcast("pii:detected", {:pii_detected, :slack, user_id, pii_details})
        
      {:no_pii} ->
        # No PII found, do nothing
        Logger.debug("No PII found in message from user #{user_id}")
    end
  end

  # Private Functions

  defp extract_content(message) do
    content = %{
      text: message.text || "",
      attachments: extract_attachments(message),
      files: extract_files(message)
    }
    
    Logger.debug("Extracted content: #{inspect(content)}")
    content
  end

  defp extract_attachments(message) do
    message.attachments || []
  end

  defp extract_files(message) do
    (message.files || [])
    |> Enum.map(fn file -> 
      %{
        url: file.url_private,
        mimetype: file.mimetype,
        name: file.name
      }
    end)
  end

  defp format_message_for_notification(message) do
    """
    Your message was removed because it contained PII (Personally Identifiable Information).
    
    Here's the content of your message so you can send it again without the PII:
    
    ```
    #{message.text}
    ```
    """
  end
end
