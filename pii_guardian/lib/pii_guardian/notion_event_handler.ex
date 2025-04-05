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

    case NotionApi.get_page(page_id) do
      {:ok, %{"archived" => false}} ->
        check_entire_page_for_pii(page_id, event)

      {:ok, %{"archived" => true}} ->
        Logger.info("Page ID: #{page_id} is archived, skipping PII check.")
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

    case NotionApi.get_page(page_id) do
      {:ok, %{"archived" => false}} ->
        updated_blocks = Map.get(data, "updated_blocks", [])
        updated_blocks_count = length(updated_blocks)

        Logger.info(
          "Page updated in workspace #{workspace_name} with ID: #{page_id}, #{updated_blocks_count} blocks updated"
        )

        if updated_blocks_count > 0 do
          # Check individual updated blocks for PII
          check_blocks_for_pii(updated_blocks, page_id, event)
        else
          check_entire_page_for_pii(page_id, event)
        end

      {:ok, %{"archived" => true}} ->
        Logger.info("Page ID: #{page_id} is archived, skipping PII check.")
    end
  end

  defp check_entire_page_for_pii(page_id, event) do
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

  defp check_blocks_for_pii(blocks, page_id, event) do
    # Check each updated block for PII
    pii_blocks =
      blocks
      |> Enum.map(fn %{"id" => block_id} ->
        {block_id, NotionPiiDetection.detect_pii_in_block(block_id)}
      end)
      |> Enum.filter(fn {_, result} -> result != :safe end)

    case pii_blocks do
      [] ->
        Logger.info("No PII detected in any of the updated blocks on page #{page_id}")
        :ok

      [{block_id, {:unsafe, _block_id, explanation}} | _] when is_binary(explanation) ->
        Logger.warning("PII detected in page #{page_id} in block #{block_id}: #{explanation}")
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

  defp notify_author(%{"id" => author_id, "type" => "person"} = author, page_id, explanation) do
    email =
      case NotionApi.get_user(author_id) do
        {:ok, user} -> get_user_email(user)
        {:error, _} -> nil
      end

    if email do
      Logger.info(
        "Notification sent to author (#{author_id}) with email #{email} about PII in page #{page_id}: #{explanation}"
      )
    else
      Logger.warning("No email found for author #{author_id}, unable to send notification")
    end
  end

  defp notify_author(_, _, _) do
    Logger.warning("Author not found or not a person, unable to send notification")
  end

  # Extract user's email from their profile data
  defp get_user_email(%{"person" => %{"email" => email}}) when is_binary(email) and email != "",
    do: email

  defp get_user_email(_), do: nil
end
