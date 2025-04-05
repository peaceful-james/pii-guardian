defmodule PiiGuardian.SlackEventHandlerTest do
  # Must be non-async for Mox
  use PiiGuardian.DataCase, async: false

  import Mox

  alias PiiGuardian.MockAnthropicPiiDetection
  alias PiiGuardian.MockSlackApi
  alias PiiGuardian.SlackEventHandler
  alias PiiGuardian.SlackEventMocks.Safe
  alias PiiGuardian.SlackEventMocks.Unsafe

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "handle/1 for safe messages" do
    test "returns ok for new message" do
      # Mock the PII detection to return safe
      expect(MockAnthropicPiiDetection, :detect_pii_in_text, fn _text -> :safe end)
      event = Safe.new_message()
      assert SlackEventHandler.handle(event) == :ok
    end
  end

  describe "handle/1 for unsafe messages" do
    test "for new message, deletes the message and DMs the author" do
      # Mock the PII detection to return unsafe
      expect(MockAnthropicPiiDetection, :detect_pii_in_text, fn _text ->
        {:unsafe, "This message contains PII: email address detected"}
      end)

      # Mock the Slackbot DM and delete operations
      MockSlackApi
      |> expect(:get_user_info, fn _user_id ->
        {:ok, %{"user" => %{"profile" => %{"real_name" => "Test User"}}}}
      end)
      |> expect(:open_dm, fn _user_id ->
        {:ok, %{"channel" => %{"id" => "D12345678"}}}
      end)
      |> expect(:post_message, fn _channel, _text, _opts ->
        {:ok, %{"ok" => true}}
      end)
      |> expect(:delete_message, fn _channel, _ts ->
        {:ok, %{"ok" => true}}
      end)

      event = Unsafe.new_message()
      assert SlackEventHandler.handle(event) == :ok
    end
  end
end
