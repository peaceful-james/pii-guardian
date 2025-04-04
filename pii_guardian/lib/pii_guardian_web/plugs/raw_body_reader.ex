defmodule PiiGuardianWeb.Plugs.RawBodyReader do
  @moduledoc """
  Puts the raw body of the request into the connection's private map.

  This is useful when validating requests against a hash of the body.
  e.g. when verifying Notion webhook events.

  The JSON Parser can mess up the order of the keys in the body,
  which can lead to incorrect hash calculations.

  Moreover, the raw body can only be read once, so we need to store it
  """
  def init(opts), do: opts

  def call(conn, _opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    Plug.Conn.put_private(conn, :raw_body, body)
  end
end
