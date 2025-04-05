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

  def delete_slack_message_and_dm_author(
        %{"channel" => channel, "text" => text, "ts" => ts, "user" => user} = _event
      ) do
    dm(channel, user, """
    Hi there!

    I just wanted to let you know that I deleted your message in the channel because it contained sensitive information.

    Here is what you wrote:

    > #{text}

    Please be careful about sharing personal information in public channels.
    """)

    delete_message(channel, ts)
  end

  def list_registry_keys do
    Registry.select(Slack.MessageServerRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
  end
end
