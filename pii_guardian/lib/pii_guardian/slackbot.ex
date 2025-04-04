defmodule PiiGuardian.Slackbot do
  @moduledoc false
  use Slack.Bot

  require Logger

  @impl true
  def handle_event("message", %{"channel" => channel, "text" => text, "user" => user}, _bot) do
    Logger.info("Received message from user: #{user}")

    if String.match?(text, ~r/hello/i) do
      send_message(channel, "Hello! <@#{user}>")
    end
  end

  def handle_event(type, payload, _bot) do
    Logger.warning("Unhandled #{type} event: #{inspect(payload)}")
    :ok
  end
end
