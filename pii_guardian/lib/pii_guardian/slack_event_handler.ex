defmodule PiiGuardian.SlackEventHandler do
  @moduledoc """
  Handles Slack events.
  """
  alias PiiGuardian.Slackbot
  alias PiiGuardian.SlackPiiDetection

  def handle(event) do
    if SlackPiiDetection.contains_pii?(event) do
      Slackbot.delete_slack_message_and_dm_author(event)
    else
      :ok
    end
  end
end
