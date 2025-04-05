defmodule PiiGuardian.AnthropicPiiDetectionTest do
  use PiiGuardian.DataCase, async: false

  import Mox

  alias PiiGuardian.AnthropicPiiDetection
  alias PiiGuardian.MockAnthropix

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "detect_pii_in_text/1" do
    test "returns :safe for nil" do
      assert AnthropicPiiDetection.detect_pii_in_text(nil) == :safe
    end

    test "returns :safe for empty string" do
      assert AnthropicPiiDetection.detect_pii_in_text("") == :safe
    end

    test "calls Anthropix and returns :safe when no PII detected" do
      # Mock the API client and its response
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: "mock"} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] No PII detected in this text."}]}}
      end)

      assert AnthropicPiiDetection.detect_pii_in_text("Hello world") == :safe
    end

    test "calls Anthropix and returns unsafe when PII detected" do
      # Mock the API client and its response
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: "mock"} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok,
         %{
           "content" => [%{"text" => "[YES_PII_UNSAFE] Email address detected: test@example.com"}]
         }}
      end)

      assert AnthropicPiiDetection.detect_pii_in_text("My email is test@example.com") ==
               {:unsafe, "Email address detected: test@example.com"}
    end
  end

  describe "detect_pii_in_file/3" do
    test "for text file, delegates to detect_pii_in_text" do
      # Mock the API client and its response
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: "mock"} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] No PII detected in this text file."}]}}
      end)

      assert AnthropicPiiDetection.detect_pii_in_file("File content", "text", "text/plain") ==
               :safe
    end

    test "for non-text file, processes as document" do
      # Mock the API client and its response
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: "mock"} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] SSN detected in document"}]}}
      end)

      content = "PDF content with PII"
      result = AnthropicPiiDetection.detect_pii_in_file(content, "pdf", "application/pdf")

      assert result == {:unsafe, "SSN detected in document"}
    end
  end
end
