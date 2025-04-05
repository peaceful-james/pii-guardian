defmodule PiiGuardian.Slackbot do
  @moduledoc """
  The "edge" of the Slack event handling system.

  This module is responsible for receiving events from Slack and
  saving them as Oban jobs for processing.
  """
  use Slack.Bot

  alias PiiGuardian.SlackApi
  alias PiiGuardian.SlackObanWorker

  require Logger

  # Use dependency injection in test environment
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
      case slack_api().get_user_info(user_id) do
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
      case slack_api().get_user_info(user_id) do
        {:ok, %{"user" => user_data}} -> user_data
        _ -> %{"profile" => %{"real_name" => "there"}}
      end

    # Get user's name for personalized greeting
    user_name = user_info["profile"]["real_name"] || user_info["name"] || "there"

    # Get file name if available
    file_name = Map.get(file, "name", "your file")

    # Delete the file
    slack_api().delete_file(file["id"])

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

  @doc """
  Send a DM to a user about their Notion page being archived due to PII.

  This function looks up a Slack user by email and sends them a direct message
  explaining that their Notion page was archived because it contained PII.

  Returns :ok if the message was sent successfully, or {:error, reason} if 
  something went wrong.
  """
  def dm_author_about_notion_pii(email, page_id, page_title, explanation) do
    # Look up the Slack user by email
    case slack_api().lookup_user_by_email(email) do
      {:ok, %{"user" => user}} ->
        Logger.info("Going to DM notion user with email #{email} on Slack.")
        user_id = user["id"]
        user_name = user["profile"]["real_name"] || user["name"] || "there"

        # Open a DM channel with the user
        case slack_api().open_dm(user_id) do
          {:ok, %{"channel" => %{"id" => dm_channel_id}}} ->
            # Send the notification message
            message = """
            =========================================================================================



            Hi #{user_name}!

            I just wanted to let you know that I archived your Notion page "#{page_title}" because it contained sensitive information.

            Page ID: #{page_id}

            Here is the reason why I archived it:

            ```
            #{explanation}
            ```

            Please be careful about sharing personal information in Notion pages that could be accessed by others.



            =========================================================================================
            """

            case slack_api().post_message(dm_channel_id, message) do
              {:ok, _} ->
                Logger.info("Successfully sent Notion PII notification to #{user_name} via Slack")
                :ok

              {:error, reason} ->
                Logger.error("Failed to send Slack message: #{inspect(reason)}")
                {:error, "Failed to send Slack message: #{inspect(reason)}"}
            end

          {:error, reason} ->
            Logger.error("Failed to open DM channel: #{inspect(reason)}")
            {:error, "Failed to open DM channel: #{inspect(reason)}"}
        end

      {:error, reason} ->
        Logger.error("Failed to find Slack user by email #{email}: #{inspect(reason)}")
        {:error, "Failed to find Slack user by email: #{inspect(reason)}"}
    end
  end

  defp slack_api, do: Application.get_env(:pii_guardian, :slack_api, SlackApi)

  def list_registry_keys do
    Registry.select(Slack.MessageServerRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
  end
end
