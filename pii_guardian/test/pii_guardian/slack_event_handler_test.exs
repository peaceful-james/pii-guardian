defmodule PiiGuardian.SlackEventHandlerTest do
  # Must be non-async for Mox
  use PiiGuardian.DataCase, async: false

  import Mox

  alias PiiGuardian.MockAnthropix
  alias PiiGuardian.MockSlackApi
  alias PiiGuardian.MockSlackbot
  alias PiiGuardian.SlackEventHandler
  alias PiiGuardian.SlackEventMocks.Safe
  alias PiiGuardian.SlackEventMocks.Unsafe

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Allow mocks to be called from any process
  setup do
    # Use global mode to allow expectations to be called from any process
    Mox.set_mox_global()
    :ok
  end

  describe "handle/1 for safe messages" do
    test "returns ok for new message" do
      # Mock Anthropix for AnthropicPiiDetection.detect_pii_in_text
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] The text is safe."}]}}
      end)

      event = Safe.new_message()
      assert SlackEventHandler.handle(event) == :ok
    end
  end

  describe "handle/1 for unsafe messages" do
    test "for new message, deletes the message and DMs the author" do
      # Mock Anthropix to return an unsafe response
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok,
         %{
           "content" => [
             %{"text" => "[YES_PII_UNSAFE] This message contains PII: email address detected"}
           ]
         }}
      end)

      # Mock the Slackbot.delete_slack_message_and_dm_author function
      expect(MockSlackbot, :delete_slack_message_and_dm_author, fn _event, _explanation ->
        :ok
      end)

      event = Unsafe.new_message()
      assert SlackEventHandler.handle(event) == :ok
    end

    test "handles file with unsafe content" do
      # Mock Anthropix calls (for both text and file)
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] Text is safe."}]}}
      end)
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] File contains PII: SSN detected"}]}}
      end)

      # Mock SlackApi for file retrieval
      MockSlackApi
      |> expect(:download_file, fn _url ->
        {:ok, %{body: "test file content"}}
      end)
      |> expect(:get_file_info, fn _file_id ->
        {:ok, %{"file" => %{"filetype" => "text", "mimetype" => "text/plain"}}}
      end)

      # Mock the Slackbot.delete_file_and_dm_author function
      expect(MockSlackbot, :delete_file_and_dm_author, fn _file, _event, _explanation ->
        :ok
      end)

      # Create an event with a file
      event = %{
        "type" => "message",
        "text" => "Check this file",
        "user" => "U12345",
        "channel" => "C12345",
        "ts" => "1234567890.123456",
        "files" => [
          %{
            "id" => "F12345",
            "url_private_download" => "https://files.slack.com/file.txt"
          }
        ]
      }

      assert SlackEventHandler.handle(event) == :ok
    end

    test "handles file with safe content" do
      # Mock Anthropix calls
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] Text is safe."}]}}
      end)
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] File is safe."}]}}
      end)

      # Mock SlackApi for file retrieval
      MockSlackApi
      |> expect(:download_file, fn _url ->
        {:ok, %{body: "test file content"}}
      end)
      |> expect(:get_file_info, fn _file_id ->
        {:ok, %{"file" => %{"filetype" => "text", "mimetype" => "text/plain"}}}
      end)

      # Create an event with a file (no need to mock Slackbot since it won't be called)
      event = %{
        "type" => "message",
        "text" => "Check this file",
        "user" => "U12345",
        "channel" => "C12345",
        "ts" => "1234567890.123456",
        "files" => [
          %{
            "id" => "F12345",
            "url_private_download" => "https://files.slack.com/file.txt"
          }
        ]
      }

      assert SlackEventHandler.handle(event) == :ok
    end
  end
end
