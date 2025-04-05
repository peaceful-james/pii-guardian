defmodule PiiGuardian.SlackEventHandlerTest do
  use PiiGuardian.DataCase, async: true

  alias PiiGuardian.SlackEventHandler
  alias PiiGuardian.SlackEventMocks.Safe
  alias PiiGuardian.SlackEventMocks.Unsafe

  describe "handle/1 for safe messages" do
    test "returns ok for new message" do
      event = Safe.new_message()
      assert SlackEventHandler.handle(event) == :ok
    end
  end

  describe "handle/1 for unsafe messages" do
    test "for new message, creates oban job to delete message and DM author" do
      event = Unsafe.new_message()
      assert SlackEventHandler.handle(event) == :ok
      flunk("finish")
    end
  end
end
