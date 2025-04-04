defmodule PiiGuardian.Slackbot do
  @moduledoc false
  use Slack.Bot

  require Logger

  @impl true
  # A silly example of old-school style bot commands.
  def handle_event("message", %{"text" => "!" <> cmd, "channel" => channel, "user" => user}, _bot) do
    case cmd do
      "roll" ->
        send_message(channel, "<@#{user}> rolled a #{Enum.random(1..6)}")

      "echo " <> text ->
        send_message(channel, text)

      _ ->
        send_message(channel, "Unknown command: #{cmd}")
    end
  end

  def handle_event("message", %{"channel" => channel, "text" => text, "user" => user}, _bot) do
    if String.match?(text, ~r/hello/i) do
      send_message(channel, "Hello! <@#{user}>")
    end
  end

  def handle_event(type, payload, _bot) do
    Logger.debug("Unhandled #{type} event: #{inspect(payload)}")
    :ok
  end
end
