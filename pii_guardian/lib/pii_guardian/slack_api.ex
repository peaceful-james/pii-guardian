defmodule PiiGuardian.SlackApi do
  @moduledoc """
  Slack API client for interacting with the Slack API.
  """
  use Tesla

  require Logger

  plug(Tesla.Middleware.BaseUrl, "https://slack.com/api")
  plug(Tesla.Middleware.JSON)
  plug(Tesla.Middleware.BearerAuth, token: bot_token())
  plug(Tesla.Middleware.Logger)

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

  Uses the admin token to post messages, allowing for more permissions than the bot token.
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

    # Create a client with admin token to ensure we have permissions
    # to post in any channel, including DMs with users
    # client =
    # Tesla.client([
    # {Tesla.Middleware.BaseUrl, "https://slack.com/api"},
    # Tesla.Middleware.JSON,
    # {Tesla.Middleware.BearerAuth, token: bot_token()},
    # Tesla.Middleware.Logger
    # ])

    # client
    # |> Tesla.post("/chat.postMessage", payload)
    # |> handle_response()

    "/chat.postMessage"
    |> post(payload)
    |> handle_response()
  end

  @doc """
  Open a direct message conversation with a user
  https://api.slack.com/methods/conversations.open

  Uses the admin token to ensure permissions to open DMs with any user.
  """
  def open_dm(user_id) do
    # Create a client with admin token to ensure we have permissions
    # to open DMs with any user
    # client =
      # Tesla.client([
        # {Tesla.Middleware.BaseUrl, "https://slack.com/api"},
        # Tesla.Middleware.JSON,
        # {Tesla.Middleware.BearerAuth, token: bot_token()},
        # Tesla.Middleware.Logger
      # ])

    # client
    # |> Tesla.post("/conversations.open", %{
      # users: user_id
    # })
    # |> handle_response()

    "/conversations.open"
    |> post(%{users: user_id})
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
  Look up a user by email address
  https://api.slack.com/methods/users.lookupByEmail
  """
  def lookup_user_by_email(email) when is_binary(email) do
    "/users.lookupByEmail"
    |> get(query: [email: email])
    |> handle_response()
  end

  @doc """
  Get user information by user ID
  https://api.slack.com/methods/users.info
  """
  def get_user_info(user_id) when is_binary(user_id) do
    "/users.info"
    |> get(query: [user: user_id])
    |> handle_response()
  end

  @doc """
  List all users in the workspace
  https://api.slack.com/methods/users.list

  Optionally takes a cursor for pagination and a limit for the number of users to return.
  """
  def list_users(cursor \\ nil, limit \\ 100) do
    query = [limit: limit]
    query = if cursor, do: Keyword.put(query, :cursor, cursor), else: query

    "/users.list"
    |> get(query: query)
    |> handle_response()
  end

  @doc """
  Get all users in the workspace, handling pagination automatically
  """
  def get_all_users do
    get_all_users_recursive(nil, [])
  end

  defp get_all_users_recursive(cursor, acc) do
    case list_users(cursor) do
      {:ok, %{"members" => members, "response_metadata" => %{"next_cursor" => next_cursor}}}
      when next_cursor != "" ->
        get_all_users_recursive(next_cursor, acc ++ members)

      {:ok, %{"members" => members}} ->
        {:ok, acc ++ members}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Download a file from Slack
  """
  def download_file(url) do
    [
      {Tesla.Middleware.Headers, [{"authorization", "Bearer #{admin_token()}"}]}
    ]
    |> Tesla.client()
    |> Tesla.get(url)
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

  defp admin_token do
    Application.fetch_env!(:slack_elixir, :admin_user_token)
  end

  defp bot_token do
    Application.fetch_env!(:pii_guardian, PiiGuardian.Slackbot)[:bot_token]
  end
end
