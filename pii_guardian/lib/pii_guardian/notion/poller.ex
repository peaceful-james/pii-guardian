defmodule PIIGuardian.Notion.Poller do
  @moduledoc """
  Polls Notion databases for new or updated pages.
  """
  use GenServer
  require Logger

  alias PIIGuardian.Config.NotionDatabases
  alias PIIGuardian.Notion.PageProcessor
  alias PIIGuardian.Notion.Connector

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Initializing Notion poller")
    
    # Start polling immediately
    schedule_polling()
    
    {:ok, %{last_polled: %{}}}
  end

  @impl true
  def handle_info(:poll, state) do
    Logger.debug("Polling Notion databases")
    
    # Get the list of watched databases
    databases = NotionDatabases.list_databases()
    
    # Poll each database
    new_last_polled = poll_databases(databases, state.last_polled)
    
    # Schedule the next polling cycle
    schedule_polling()
    
    {:noreply, %{state | last_polled: new_last_polled}}
  end

  # Private functions

  defp poll_databases(databases, last_polled) do
    Enum.reduce(databases, last_polled, fn database_id, acc ->
      poll_database(database_id, Map.get(acc, database_id))
      |> case do
        {:ok, last_polled_time} ->
          Map.put(acc, database_id, last_polled_time)
        _ ->
          acc
      end
    end)
  end

  defp poll_database(database_id, last_polled_time) do
    # Create a filter for pages updated since last poll
    filter = if last_polled_time do
      %{
        property: "last_edited_time",
        date: %{
          on_or_after: last_polled_time
        }
      }
    else
      # First poll, limit to recent entries
      %{
        property: "created_time",
        date: %{
          past_week: %{}
        }
      }
    end
    
    # Query the database for recently updated pages
    case Connector.query_database(database_id, filter) do
      {:ok, %{"results" => pages}} ->
        process_pages(pages, database_id)
        
        # Update last_polled_time with current time
        now = DateTime.utc_now() |> DateTime.to_iso8601()
        {:ok, now}
        
      {:error, error} ->
        Logger.error("Failed to poll database #{database_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp process_pages(pages, database_id) do
    Logger.info("Processing #{length(pages)} pages from database #{database_id}")
    
    Enum.each(pages, fn page ->
      # Process each page in a separate task
      Task.start(fn -> PageProcessor.process_page(page, database_id) end)
    end)
  end

  defp schedule_polling do
    # Get polling interval from config (default: 60 seconds)
    interval = Application.get_env(:pii_guardian, PIIGuardian.Notion)[:polling_interval] || 60_000
    Process.send_after(self(), :poll, interval)
  end
end
