defmodule PiiGuardian.Slackbot do
  @moduledoc """
  The "edge" of the Slack event handling system.

  This module is responsible for receiving events from Slack and
  saving them as Oban jobs for processing.
  """
  use Slack.Bot

  alias PiiGuardian.SlackObanWorker

  @impl Slack.Bot
  def handle_event("message", event, _bot) do
    SlackObanWorker.enqueue_event_to_handle(event)
  end
end
