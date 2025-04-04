defmodule PiiGuardianWeb.Plugs.NotionVerificationPlug do
  @moduledoc """
  A plug to verify Notion webhook event payloads.
  """
  import Plug.Conn

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    [verification_token: verification_token] =
      Application.get_env(:pii_guardian, __MODULE__, :verification_token)

    ["sha256=" <> sha256_hash | _] = get_req_header(conn, "x-notion-signature")
    raw_body = conn.private[:raw_body]

    calculated_signature =
      :hmac
      |> :crypto.mac(:sha256, verification_token, raw_body)
      |> Base.encode16(case: :lower)

    if Plug.Crypto.secure_compare(calculated_signature, sha256_hash) do
      conn
    else
      Logger.warning("Notion webhook verification failed")
      halt_with_unauthorized(conn)
    end
  end

  defp halt_with_unauthorized(conn) do
    conn
    # |> put_resp_content_type("application/json")
    # |> send_resp(401, JSON.encode!(%{error: "Unauthorized"}))
    # |> halt()
  end
end
