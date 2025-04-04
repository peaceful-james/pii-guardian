defmodule NotionVerifier do
  @doc """
  Verifies a Notion webhook signature to ensure the request is legitimate.

  # Example usage:
  ```
  verification_token = "local_secret_tMrlL1qK5vuQAh1b6cZGhFChZTSYJlce98V0pYn7yBl"
  body = %{"verification_token" => "local_secret_tMrlL1qK5vuQAh1b6cZGhFChZTSYJlce98V0pYn7yBl"}
  headers = %{"X-Notion-Signature" => "some-signature-value"}

  if !NotionVerifier.verify_webhook(body, headers, verification_token) do
    # Ignore the event
    nil
  end
  ```
  """
  def verify_webhook(body, headers, verification_token) do
    # Convert body to JSON string
    body_json = Jason.encode!(body)

    # Calculate signature
    calculated_signature = "sha256=" <> (
      :crypto.mac(:hmac, :sha256, verification_token, body_json)
      |> Base.encode16(case: :lower)
    )

    # Extract Notion signature from headers
    notion_signature = headers["X-Notion-Signature"]

    # Compare signatures using constant-time comparison
    case notion_signature do
      nil -> false
      _ -> Plug.Crypto.secure_compare(calculated_signature, notion_signature)
    end
  end
end

