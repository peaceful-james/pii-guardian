defmodule PiiGuardianWeb.Plugs.NotionVerificationPlugTest do
  use PiiGuardianWeb.ConnCase, async: true

  alias PiiGuardianWeb.Plugs.NotionVerificationPlug

  setup do
    # Set up a sample verification token for tests
    verification_token = "test_verification_token"

    Application.put_env(
      :pii_guardian,
      PiiGuardianWeb.Plugs.NotionVerificationPlug,
      verification_token: verification_token
    )

    # Return the token to use in tests
    %{verification_token: verification_token}
  end

  describe "call/2" do
    test "allows valid requests through", %{conn: conn, verification_token: token} do
      # Create a request body
      body = "{\"example\":\"payload\"}"

      # Calculate the signature as Notion would
      signature =
        :hmac
        |> :crypto.mac(:sha256, token, body)
        |> Base.encode16(case: :lower)

      # Build conn with the necessary data
      conn =
        conn
        |> put_req_header("x-notion-signature", "sha256=#{signature}")
        |> Map.put(:private, %{raw_body: body})

      # Pass the conn through the plug
      result = NotionVerificationPlug.call(conn, [])

      # Assert the connection was not halted
      refute result.halted
    end

    test "rejects requests with invalid signatures", %{conn: conn, verification_token: _token} do
      # Create a request body
      body = "{\"example\":\"payload\"}"

      # Calculate an invalid signature
      invalid_signature = "invalid_signature"

      # Build conn with the necessary data
      conn =
        conn
        |> put_req_header("x-notion-signature", "sha256=#{invalid_signature}")
        |> Map.put(:private, %{raw_body: body})

      captured_log =
        capture_log([level: :warning], fn ->
          # Pass the conn through the plug
          result = NotionVerificationPlug.call(conn, [])

          # Assert the connection was halted with a 401 status
          assert result.halted
          assert result.status == 401
          assert result.resp_body == Jason.encode!(%{error: "Unauthorized"})
        end)

      assert captured_log =~ "Notion webhook verification failed"
    end

    test "rejects requests with missing signature header", %{conn: conn} do
      # Create a request body
      body = "{\"example\":\"payload\"}"

      # Build conn with missing header
      conn = Map.put(conn, :private, %{raw_body: body})

      # Expect an error when the header is missing
      assert_raise MatchError, fn ->
        NotionVerificationPlug.call(conn, [])
      end
    end

    test "rejects requests with tampered body", %{conn: conn, verification_token: token} do
      # Create an original request body and calculate its signature
      original_body = "{\"example\":\"payload\"}"

      signature =
        :hmac
        |> :crypto.mac(:sha256, token, original_body)
        |> Base.encode16(case: :lower)

      # Create a tampered body but use the original signature
      tampered_body = "{\"example\":\"malicious\"}"

      # Build conn with the tampered body but original signature
      conn =
        conn
        |> put_req_header("x-notion-signature", "sha256=#{signature}")
        |> Map.put(:private, %{raw_body: tampered_body})

      captured_log =
        capture_log([level: :warning], fn ->
          # Pass the conn through the plug
          result = NotionVerificationPlug.call(conn, [])

          # Assert the connection was halted with a 401 status
          assert result.halted
          assert result.status == 401
          assert result.resp_body == Jason.encode!(%{error: "Unauthorized"})
        end)

      assert captured_log =~ "Notion webhook verification failed"
    end

    test "plug initialization", %{conn: _conn} do
      # Test that init simply returns its options
      opts = [some: "option"]
      assert NotionVerificationPlug.init(opts) == opts
    end
  end
end
