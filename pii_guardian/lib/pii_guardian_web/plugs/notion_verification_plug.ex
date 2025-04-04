defmodule PiiGuardianWeb.Plugs.NotionVerificationPlug do
  @moduledoc """
  A plug to verify Notion webhook event payloads.
  Uses the NotionVerifier module to validate the request signature.
  """
  import Plug.Conn

  alias PiiGuardian.NotionVerifier

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, raw_body, conn} <- read_body(conn, []),
         signature = conn |> get_req_header("x-notion-signature") |> List.first(),
         timestamp = conn |> get_req_header("x-notion-timestamp") |> List.first(),
         true <- signature != nil && timestamp != nil,
         {:ok, :verified} <- NotionVerifier.verify_webhook(raw_body, signature, timestamp) do
      # Restore the raw body for the controller to access
      assign(conn, :raw_body, raw_body)
    else
      {:ok, _conn, nil} ->
        Logger.warning("Notion webhook verification failed: Missing request body")
        halt_with_unauthorized(conn)

      nil ->
        Logger.warning("Notion webhook verification failed: Missing headers")
        halt_with_unauthorized(conn)

      {:error, reason} ->
        Logger.warning("Notion webhook verification failed: #{inspect(reason)}")
        halt_with_unauthorized(conn)

      _ ->
        Logger.warning("Notion webhook verification failed: Unknown error")
        halt_with_unauthorized(conn)
    end
  end

  defp halt_with_unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "Unauthorized"}))
    |> halt()
  end
end
