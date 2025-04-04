defmodule PiiGuardianWeb.NotionController do
  use PiiGuardianWeb, :controller

  require Logger

  @doc """
  Handles incoming webhook events from Notion API.
  Simply logs the event at info level and returns a successful response.
  """
  def events(conn, params) do
    Logger.info("Received Notion webhook event: #{inspect(params)}")

    # Return a 200 OK response to acknowledge receipt
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{ok: true}))
  end
end
