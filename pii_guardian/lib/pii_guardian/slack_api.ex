defmodule PiiGuardian.SlackApi do
  @moduledoc """
  Slack API client for interacting with the Slack API.
  """
  use Tesla

  require Logger

  plug Tesla.Middleware.BaseUrl, "https://slack.com/api"
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.BearerAuth, token: slack_token()
  plug Tesla.Middleware.Logger

  @doc """
  Retrieve information about a file
  https://api.slack.com/methods/files.info
  """
  def get_file_info(file_id) do
    "/files.info"
    |> get(query: [file: file_id])
    |> handle_response()
  end

  @doc """
  Delete a message
  https://api.slack.com/methods/chat.delete
  """
  def delete_message(channel, ts) do
    "/chat.delete"
    |> post(%{
      channel: channel,
      ts: ts
    })
    |> handle_response()
  end

  @doc """
  Post a message to a channel
  https://api.slack.com/methods/chat.postMessage
  """
  def post_message(channel, text, opts \\ %{}) do
    payload =
      Map.merge(
        %{
          channel: channel,
          text: text
        },
        opts
      )

    "/chat.postMessage"
    |> post(payload)
    |> handle_response()
  end

  @doc """
  Open a direct message conversation with a user
  https://api.slack.com/methods/conversations.open
  """
  def open_dm(user_id) do
    "/conversations.open"
    |> post(%{
      users: user_id
    })
    |> handle_response()
  end

  @doc """
  Delete a file
  https://api.slack.com/methods/files.delete
  """
  def delete_file(file_id) do
    "/files.delete"
    |> post(%{
      file: file_id
    })
    |> handle_response()
  end

  @doc """
  Download a file from Slack
  """
  def download_file(url) do
    [
      {Tesla.Middleware.Headers, [{"authorization", "Bearer #{slack_token()}"}]}
    ]
    |> Tesla.client()
    |> Tesla.get(url)
    |> handle_response()
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    if body["ok"] do
      {:ok, body}
    else
      Logger.error("Slack API error: #{inspect(body)}")
      {:error, body["error"] || "Unknown Slack API error"}
    end
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.error("Slack API HTTP error: #{status}, #{inspect(body)}")
    {:error, "HTTP error #{status}"}
  end

  defp handle_response({:error, error}) do
    Logger.error("Slack API client error: #{inspect(error)}")
    {:error, "Client error: #{inspect(error)}"}
  end

  defp slack_token do
    Application.fetch_env!(:pii_guardian, PiiGuardian.Slackbot)[:bot_token]
  end
end
