defmodule PiiGuardian.NotionEventHandler do
  @moduledoc """
  Handles Notion events.
  """
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
    # Implement page creation handling logic here
    :ok
  end

  defp handle_page_deleted(event) do
    %{
      "entity" => %{"id" => page_id},
      "workspace_name" => workspace_name
    } = event

    Logger.info("Page deleted in workspace #{workspace_name} with ID: #{page_id}")
    # Implement page deletion handling logic here
    :ok
  end

  defp handle_page_updated(event) do
    %{
      "entity" => %{"id" => page_id},
      "workspace_name" => workspace_name,
      "data" => data
    } = event

    updated_blocks_count = data |> Map.get("updated_blocks", []) |> length()

    Logger.info(
      "Page updated in workspace #{workspace_name} with ID: #{page_id}, #{updated_blocks_count} blocks updated"
    )

    # Implement page update handling logic here
    :ok
  end
end
