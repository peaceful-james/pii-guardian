defmodule PiiGuardian.NotionEventHandler do
  @moduledoc """
  Handles Notion events.
  """
  alias PiiGuardian.NotionApi
  alias PiiGuardian.NotionPiiDetection

  require Logger

  @doc """
  Handles a Notion event.
  """
  def handle(%{"type" => event_type} = event) do
    Logger.info("Processing Notion event of type: #{event_type}")

    case event_type do
      "page.created" ->
        handle_page_created(event)

      "page.deleted" ->
        handle_page_deleted(event)

      "page.content_updated" ->
        handle_page_updated(event)

      _ ->
        Logger.info("Unhandled Notion event type: #{event_type}")
        :ok
    end
  end

  defp handle_page_created(event) do
    %{
      "entity" => %{"id" => page_id},
      "workspace_name" => workspace_name
    } = event

    Logger.info("Page created in workspace #{workspace_name} with ID: #{page_id}")

    # Check the new page for PII
    case NotionPiiDetection.detect_pii_in_page(page_id) do
      :safe ->
        Logger.info("No PII detected in newly created page #{page_id}")
        :ok

      {:unsafe, ^page_id, explanation} when is_binary(explanation) ->
        Logger.warning("PII detected in newly created page #{page_id}: #{explanation}")
        # Archive the page with PII
        delete_page_and_notify_authors(page_id, event, explanation)

      {:unsafe, ^page_id, unsafe_block_file_results} when is_list(unsafe_block_file_results) ->
        explanation =
          Enum.map_join(unsafe_block_file_results, "\n\n", fn %{explanation: explanation} ->
            explanation
          end)

        Logger.warning(
          "Unsafe block file(s) detected in page ID #{page_id}, explanation: #{explanation}"
        )

        delete_page_and_notify_authors(page_id, event, explanation)
    end
  end

  defp handle_page_deleted(event) do
    %{
      "entity" => %{"id" => page_id},
      "workspace_name" => workspace_name
    } = event

    Logger.info("Page deleted in workspace #{workspace_name} with ID: #{page_id}")
    # No action needed for deleted pages
    :ok
  end

  defp handle_page_updated(event) do
    %{
      "entity" => %{"id" => page_id},
      "workspace_name" => workspace_name,
      "data" => data
    } = event

    updated_blocks = Map.get(data, "updated_blocks", [])
    updated_blocks_count = length(updated_blocks)

    Logger.info(
      "Page updated in workspace #{workspace_name} with ID: #{page_id}, #{updated_blocks_count} blocks updated"
    )

    if updated_blocks_count > 0 do
      # Check individual updated blocks for PII
      check_blocks_for_pii(updated_blocks, page_id, event)
    else
      # If no specific blocks mentioned, check the entire page
      case NotionPiiDetection.detect_pii_in_page(page_id) do
        :safe ->
          Logger.info("No PII detected in updated page #{page_id}")
          :ok

        {:unsafe, _, explanation} ->
          Logger.warning("PII detected in updated page #{page_id}: #{explanation}")
          # Archive the page with PII
          delete_page_and_notify_authors(page_id, event, explanation)
      end
    end
  end

  defp check_blocks_for_pii(blocks, page_id, event) do
    # Check each updated block for PII
    pii_blocks =
      blocks
      |> Enum.map(fn %{"id" => block_id} ->
        {block_id, NotionPiiDetection.detect_pii_in_block(block_id)}
      end)
      |> Enum.filter(fn {_, result} -> result != :safe end)

    if pii_blocks == [] do
      Logger.info("No PII detected in any of the updated blocks on page #{page_id}")
      :ok
    else
      # Get the first block with PII and its explanation
      {block_id, {:unsafe, _, explanation}} = List.first(pii_blocks)

      Logger.warning("PII detected in block #{block_id} on page #{page_id}: #{explanation}")

      # Archive the page with PII
      delete_page_and_notify_authors(page_id, event, explanation)
    end
  end

  defp delete_page_and_notify_authors(page_id, event, explanation) do
    # Get the authors from the event
    authors = Map.get(event, "authors", [])

    # Archive (delete) the page
    case NotionApi.delete_page(page_id) do
      {:ok, _} ->
        Logger.info("Successfully archived page #{page_id} containing PII")

        # Notify authors
        Enum.each(authors, fn author ->
          notify_author(author, page_id, explanation)
        end)

        :ok

      {:error, reason} ->
        Logger.error("Failed to archive page #{page_id}: #{reason}")
        {:error, reason}
    end
  end

  defp notify_author(%{"id" => author_id, "type" => "person"}, page_id, explanation) do
    # In a real system, you would use Notion API to send a message to the user
    # or perhaps use email notification, Slack integration, etc.
    # For now, we'll just log this
    Logger.info(
      "Notification sent to author #{author_id} about PII in page #{page_id}: #{explanation}"
    )

    :ok
  end

  defp notify_author(_, _, _), do: :ok
end
