defmodule PiiGuardian.SlackEventHandler do
  @moduledoc """
  Handles Slack events.
  """
  alias PiiGuardian.Slackbot
  alias PiiGuardian.SlackPiiDetection

  require Logger

  defp slackbot, do: Application.get_env(:pii_guardian, :slackbot, Slackbot)

  def handle(event) do
    Logger.debug("SlackEventHandler received event: #{inspect(event, pretty: true)}")

    case SlackPiiDetection.detect_pii_in_text(event) do
      {:unsafe, explanation} ->
        slackbot().delete_slack_message_and_dm_author(event, explanation)

      :safe ->
        # No action needed for safe events
        :noop
    end

    for file <- Map.get(event, "files", []) do
      case SlackPiiDetection.detect_pii_in_file(file) do
        {:unsafe, explanation} ->
          slackbot().delete_file_and_dm_author(file, event, explanation)

        :safe ->
          # No action needed for safe files
          :noop
      end
    end

    :ok
  end
end
