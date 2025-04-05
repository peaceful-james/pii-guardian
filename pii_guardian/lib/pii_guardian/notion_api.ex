defmodule PiiGuardian.NotionApi do
  @moduledoc """
  Notion API client for interacting with the Notion API.

  Provides functions to retrieve page content and delete pages.
  """
  use Tesla

  require Logger

  plug Tesla.Middleware.BaseUrl, "https://api.notion.com/v1"
  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.BearerAuth, token: notion_token()
  plug Tesla.Middleware.Headers, [{"Notion-Version", "2022-06-28"}]
  plug Tesla.Middleware.Logger

  @doc """
  Retrieve a page by ID
  https://developers.notion.com/reference/retrieve-a-page
  """
  def get_page(page_id) do
    "/pages/#{page_id}"
    |> get()
    |> handle_response()
  end

  @doc """
  Retrieve page content (blocks)
  https://developers.notion.com/reference/retrieve-block-children
  """
  def get_page_content(page_id, start_cursor \\ nil, page_size \\ 100) do
    query = [page_size: page_size]
    query = if start_cursor, do: Keyword.put(query, :start_cursor, start_cursor), else: query

    "/blocks/#{page_id}/children"
    |> get(query: query)
    |> handle_response()
  end

  @doc """
  Delete (archive) a page - There is no direct API to delete a page, but we can archive it
  https://developers.notion.com/reference/update-a-page
  """
  def delete_page(page_id) do
    "/pages/#{page_id}"
    |> patch(%{
      "archived" => true
    })
    |> handle_response()
  end

  @doc """
  Retrieve a block by ID
  https://developers.notion.com/reference/retrieve-a-block
  """
  def get_block(block_id) do
    "/blocks/#{block_id}"
    |> get()
    |> handle_response()
  end

  @doc """
  Delete (archive) a block
  https://developers.notion.com/reference/update-a-block
  """
  def delete_block(block_id) do
    "/blocks/#{block_id}"
    |> patch(%{
      "archived" => true
    })
    |> handle_response()
  end

  @doc """
  Recursively fetch all blocks for a page, handling pagination
  """
  def get_all_page_content(page_id) do
    get_all_page_content_recursive(page_id, nil, [])
  end

  defp get_all_page_content_recursive(page_id, start_cursor, acc) do
    case get_page_content(page_id, start_cursor) do
      {:ok, %{"results" => results, "has_more" => true, "next_cursor" => next_cursor}} ->
        get_all_page_content_recursive(page_id, next_cursor, acc ++ results)

      {:ok, %{"results" => results}} ->
        {:ok, acc ++ results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.error("Notion API HTTP error: #{status}, #{inspect(body)}")
    {:error, "HTTP error #{status}: #{get_error_message(body)}"}
  end

  defp handle_response({:error, error}) do
    Logger.error("Notion API client error: #{inspect(error)}")
    {:error, "Client error: #{inspect(error)}"}
  end

  @doc """
  Download a file from a URL
  This can be used for files referenced in Notion, which may be hosted on external services
  """
  def download_file(url) do
    # Create a Tesla client for downloading files
    # We don't use bearer auth for this since the URL should already have authentication
    # embedded or be publicly accessible
    client =
      Tesla.client([
        Tesla.Middleware.FollowRedirects
      ])

    client
    |> Tesla.get(url)
    |> handle_download_response()
  end

  defp handle_download_response({:ok, %{status: status, body: body, headers: headers}}) when status in 200..299 do
    {"content-type", mimetype} = List.keyfind(headers, "content-type", 0)
    {:ok, %{body: body, mimetype: mimetype}}
  end

  defp handle_download_response({:ok, %{status: status}}) do
    Logger.error("Failed to download file: HTTP error #{status}")
    {:error, "HTTP error #{status}"}
  end

  defp handle_download_response({:error, error}) do
    Logger.error("Failed to download file: #{inspect(error)}")
    {:error, "Download error: #{inspect(error)}"}
  end

  defp get_error_message(%{"message" => message}), do: message
  defp get_error_message(_), do: "Unknown error"

  defp notion_token do
    Application.fetch_env!(:pii_guardian, :notion_api_token)
  end
end
