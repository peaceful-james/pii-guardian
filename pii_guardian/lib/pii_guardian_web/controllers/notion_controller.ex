defmodule PiiGuardianWeb.NotionController do
  use PiiGuardianWeb, :controller

  alias PiiGuardian.NotionObanWorker

  require Logger

  @doc """
  Handles incoming webhook events from Notion API.
  Creates an Oban job to process the event asynchronously,
  similar to how PiiGuardian.Slackbot handles events.
  """
  def events(conn, params) do
    Logger.info("Received Notion webhook event: #{inspect(params)}")

    case NotionObanWorker.enqueue_event_to_handle(params) do
      {:ok, _job} ->
        Logger.debug("Successfully enqueued Notion event")

      {:error, error} ->
        Logger.error("Failed to enqueue Notion event: #{inspect(error)}")
    end

    # Return a 200 OK response to acknowledge receipt
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{ok: true}))
  end
end
