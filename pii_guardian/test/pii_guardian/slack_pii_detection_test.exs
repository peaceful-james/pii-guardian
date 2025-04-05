defmodule PiiGuardian.SlackPiiDetectionTest do
  use PiiGuardian.DataCase, async: false

  import Mox

  alias PiiGuardian.MockAnthropix
  alias PiiGuardian.MockSlackApi
  alias PiiGuardian.SlackPiiDetection

  setup :verify_on_exit!

  # Allow mocks to be called from any process
  setup do
    Mox.set_mox_global()
    :ok
  end

  describe "detect_pii_in_text/1" do
    test "correctly detects safe text" do
      # Mock Anthropix to mock the Anthropic API calls
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] The text is safe."}]}}
      end)

      event = %{"type" => "message", "text" => "Hello world"}
      assert SlackPiiDetection.detect_pii_in_text(event) == :safe
    end

    test "correctly detects unsafe text" do
      # Mock Anthropix to mock the Anthropic API calls
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] Contains email addresses"}]}}
      end)

      event = %{"type" => "message", "text" => "Hello world"}
      result = SlackPiiDetection.detect_pii_in_text(event)
      assert elem(result, 0) == :unsafe
      result |> elem(1) |> String.contains?("Contains email addresses") |> assert()
    end
  end

  describe "detect_pii_in_file/1" do
    test "successfully detects PII in a file" do
      file_id = "F12345"
      url = "https://files.slack.com/files-pri/T123456-F12345/file.txt"
      file = %{"id" => file_id, "url_private_download" => url}

      # Mock Anthropix for file content detection
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] Contains email addresses"}]}}
      end)

      # Mock the API responses
      MockSlackApi
      |> expect(:download_file, fn ^url ->
        {:ok, %{body: "test file content"}}
      end)
      |> expect(:get_file_info, fn ^file_id ->
        {:ok, %{"file" => %{"filetype" => "text", "mimetype" => "text/plain"}}}
      end)

      result = SlackPiiDetection.detect_pii_in_file(file)
      assert elem(result, 0) == :unsafe
      result |> elem(1) |> String.contains?("Contains email addresses") |> assert()
    end

    test "returns unsafe when file download fails" do
      file_id = "F12345"
      url = "https://files.slack.com/files-pri/T123456-F12345/file.txt"
      file = %{"id" => file_id, "url_private_download" => url}

      # Mock file download failure
      expect(MockSlackApi, :download_file, fn ^url ->
        {:error, "Failed to download file"}
      end)

      captured_log =
        capture_log([level: :error], fn ->
          result = SlackPiiDetection.detect_pii_in_file(file)
          assert result == {:unsafe, "Failed to retrieve file info"}
        end)

      assert captured_log =~ "Failed to retrieve file info for file ID: F12345"
    end

    test "returns unsafe when getting file info fails" do
      file_id = "F12345"
      url = "https://files.slack.com/files-pri/T123456-F12345/file.txt"
      file = %{"id" => file_id, "url_private_download" => url}

      # Mock file download success but get_file_info failure
      MockSlackApi
      |> expect(:download_file, fn ^url ->
        {:ok, %{body: "test file content"}}
      end)
      |> expect(:get_file_info, fn ^file_id ->
        {:error, "File not found"}
      end)

      captured_log =
        capture_log([level: :error], fn ->
          result = SlackPiiDetection.detect_pii_in_file(file)
          assert result == {:unsafe, "Failed to retrieve file info"}
        end)

      assert captured_log =~ "Failed to retrieve file info for file ID: F12345"
    end
  end
end
