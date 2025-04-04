defmodule PIIGuardian.Notion.Actions do
  @moduledoc """
  Functions for performing actions on Notion, such as deleting pages
  and notifying authors via Slack.
  """
  require Logger

  alias PIIGuardian.Notion.Connector
  alias PIIGuardian.Users.Resolver
  alias PIIGuardian.Slack.Actions, as: SlackActions

  @doc """
  Deletes a Notion page (archives it).
  
  ## Parameters
    - page_id: The ID of the page to delete
  """
  def delete_page(page_id) do
    Logger.info("Deleting Notion page #{page_id}")
    
    case Connector.delete_page(page_id) do
      {:ok, _} -> 
        Logger.info("Successfully deleted Notion page #{page_id}")
        :ok
      {:error, error} -> 
        Logger.error("Failed to delete Notion page: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Notifies the author of a Notion page about PII found in their content.
  
  ## Parameters
    - author: The Notion user who created the page (email or ID)
    - page_title: The title of the page
    - content: The extracted content of the page
    - pii_details: Details about the PII that was found
  """
  def notify_author(author, page_title, content, pii_details) do
    Logger.info("Notifying author #{author} about PII in Notion page")
    
    # Resolve the Notion user to a Slack user
    case Resolver.get_slack_user_for_notion_user(author) do
      {:ok, slack_user_id} ->
        # Send notification via Slack
        message = build_notification(page_title, content, pii_details)
        SlackActions.notify_user(slack_user_id, message, pii_details)
        
      {:error, reason} ->
        Logger.error("Failed to resolve Notion user to Slack user: #{reason}")
        {:error, :user_not_found}
    end
  end

  # Private functions

  defp build_notification(page_title, content, pii_details) do
    property_text = format_properties(content.properties)
    
    """
    Your Notion page "#{page_title}" was removed because it contained PII (Personally Identifiable Information).
    
    Here's the content of your page so you can recreate it without the PII:
    
    ```
    #{property_text}
    ```
    
    PII types detected: #{format_pii_types(pii_details)}
    """
  end

  defp format_properties(properties) do
    properties
    |> Enum.map(fn {name, value} -> "#{name}: #{value}" end)
    |> Enum.join("\n")
  end

  defp format_pii_types(pii_details) do
    pii_details.types
    |> Enum.map(&"*#{&1}*")
    |> Enum.join(", ")
  end
end
