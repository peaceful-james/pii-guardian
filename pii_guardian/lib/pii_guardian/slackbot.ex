defmodule PiiGuardian.Slackbot do
  @moduledoc """
  The "edge" of the Slack event handling system.

  This module is responsible for receiving events from Slack and
  saving them as Oban jobs for processing.
  """
  use Slack.Bot

  alias PiiGuardian.SlackObanWorker

  require Logger

  @impl Slack.Bot
  def handle_event("message", event, _bot) do
    Logger.debug("Got Slack event: #{inspect(event, pretty: true)}")
    SlackObanWorker.enqueue_event_to_handle(event)
  end

  def delete_slack_message_and_dm_author(
        %{"channel" => channel, "text" => text, "ts" => ts, "user" => user_id} = _event,
        explanation
      ) do
    # Get user information for personalized messaging
    user_info =
      case PiiGuardian.SlackApi.get_user_info(user_id) do
        {:ok, %{"user" => user_data}} -> user_data
        _ -> %{"profile" => %{"real_name" => "there"}}
      end

    # Get user's name for personalized greeting
    user_name = user_info["profile"]["real_name"] || user_info["name"] || "there"

    dm(channel, user_id, """
    =========================================================================================



    Hi #{user_name}!

    I just wanted to let you know that I deleted your message in the channel because it contained sensitive information.

    Here is what you wrote:

    ```
    #{text}
    ```

    Here is the reason why I deleted it:

    ```
    #{explanation}
    ```

    Please be careful about sharing personal information in public channels.



    =========================================================================================
    """)

    delete_message(channel, ts)
  end

  def delete_file_and_dm_author(
        file,
        %{"channel" => channel, "user" => user_id} = _event,
        explanation
      ) do
    # Get user information for personalized messaging
    user_info =
      case PiiGuardian.SlackApi.get_user_info(user_id) do
        {:ok, %{"user" => user_data}} -> user_data
        _ -> %{"profile" => %{"real_name" => "there"}}
      end

    # Get user's name for personalized greeting
    user_name = user_info["profile"]["real_name"] || user_info["name"] || "there"

    # Get file name if available
    file_name = Map.get(file, "name", "your file")

    # Delete the file
    PiiGuardian.SlackApi.delete_file(file["id"])

    dm(channel, user_id, """
    =========================================================================================



    Hi #{user_name}!

    I just wanted to let you know that I deleted your file "#{file_name}" because it contained sensitive information.

    Here is the reason why I deleted it:

    ```
    #{explanation}
    ```

    Please be careful about sharing files containing personal information in public channels.



    =========================================================================================
    """)
  end

  def list_registry_keys do
    Registry.select(Slack.MessageServerRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
  end
end
