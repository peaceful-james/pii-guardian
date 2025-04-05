defmodule PiiGuardian.NotionPiiDetection do
  @moduledoc """
  Detect if a Notion page or block contains PII (Personally Identifiable Information).
  """
  alias PiiGuardian.AnthropicPiiDetection
  alias PiiGuardian.NotionApi

  require Logger

  @doc """
  Detects if a Notion page content contains PII.
  Takes a page_id and checks all text blocks for PII.
  """
  @spec detect_pii_in_page(String.t()) :: :safe | {:unsafe, String.t(), String.t()}
  def detect_pii_in_page(page_id) when is_binary(page_id) do
    Logger.debug("Checking Notion page for PII: #{page_id}")

    case page_id |> NotionApi.get_all_page_content() do
      {:ok, blocks} ->
        Logger.debug("Retrieved blocks for page ID: #{page_id}")
        check_blocks_for_pii(blocks, page_id)

      {:error, reason} ->
        Logger.error("Failed to retrieve content for page ID: #{page_id}, reason: #{reason}")
        {:unsafe, page_id, "Failed to retrieve page content: #{reason}"}
    end
  end

  @doc """
  Detects if a specific Notion block contains PII.
  Takes a block_id and checks its content for PII.
  """
  @spec detect_pii_in_block(String.t()) :: :safe | {:unsafe, String.t(), String.t()}
  def detect_pii_in_block(block_id) when is_binary(block_id) do
    Logger.debug("Checking Notion block for PII: #{block_id}")

    case NotionApi.get_block(block_id) do
      {:ok, block} ->
        case extract_text_from_block(block) do
          nil ->
            # Non-text block, check if it's a file
            check_file_in_block(block, block_id)

          text when is_binary(text) ->
            case AnthropicPiiDetection.detect_pii_in_text(text) do
              :safe ->
                :safe

              {:unsafe, explanation} ->
                {:unsafe, block_id, explanation}
            end
        end

      {:error, reason} ->
        Logger.error("Failed to retrieve block: #{block_id}, reason: #{reason}")
        {:unsafe, block_id, "Failed to retrieve block content: #{reason}"}
    end
  end

  # Private helper functions

  defp check_blocks_for_pii(blocks, page_id) do
    # Extract all text content from blocks
    text_content =
      blocks
      |> Enum.map(&extract_text_from_block/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n\n")
      |> String.trim()

    # If there's no text content, it's safe
    if text_content == "" do
      :safe
    else
      # Check the combined text for PII
      case AnthropicPiiDetection.detect_pii_in_text(text_content) do
        :safe ->
          # If combined text is safe, check for file blocks
          check_files_in_blocks(blocks, page_id)

        {:unsafe, explanation} ->
          {:unsafe, page_id, explanation}
      end
    end
  end

  defp check_files_in_blocks(blocks, page_id) do
    # Find file blocks
    file_blocks = Enum.filter(blocks, &is_file_block?/1)

    # If no file blocks, it's safe
    if file_blocks == [] do
      :safe
    else
      # Check each file block for PII
      Enum.reduce_while(file_blocks, :safe, fn block, _acc ->
        block_id = block["id"]

        case check_file_in_block(block, block_id) do
          :safe -> {:cont, :safe}
          {:unsafe, _, explanation} -> {:halt, {:unsafe, page_id, explanation}}
        end
      end)
    end
  end

  defp is_file_block?(%{"type" => "file"}), do: true
  defp is_file_block?(%{"type" => "image"}), do: true
  defp is_file_block?(%{"type" => "pdf"}), do: true
  defp is_file_block?(_), do: false

  defp check_file_in_block(%{"type" => file_type} = block, block_id)
       when file_type in ["file", "image", "pdf"] do
    # Extract file data from the block using the file_type as the key
    file_data = Map.get(block, file_type)

    # Extract file URL from the block
    file_url = get_file_url(file_data, file_type)

    if file_url do
      Logger.debug("Retrieving file content from URL: #{file_url}")

      case NotionApi.download_file(file_url) do
        {:ok, body} ->
          # Determine the mimetype based on file_type
          mimetype = determine_mimetype(file_type, file_data)

          # Check the file content for PII
          case AnthropicPiiDetection.detect_pii_in_file(body, file_type, mimetype) do
            :safe -> :safe
            {:unsafe, explanation} -> {:unsafe, block_id, explanation}
          end

        {:error, reason} ->
          Logger.error("Failed to download file: #{reason}")
          {:unsafe, block_id, "Failed to download file for PII analysis: #{reason}"}
      end
    else
      Logger.error("No file URL found in block: #{block_id}")
      {:unsafe, block_id, "No file URL found in block"}
    end
  end

  defp check_file_in_block(_block, _block_id), do: :safe

  # Extract text from various block types
  defp extract_text_from_block(%{
         "type" => "paragraph",
         "paragraph" => %{"rich_text" => rich_text}
       }) do
    extract_text_from_rich_text(rich_text)
  end

  defp extract_text_from_block(%{
         "type" => "heading_1",
         "heading_1" => %{"rich_text" => rich_text}
       }) do
    extract_text_from_rich_text(rich_text)
  end

  defp extract_text_from_block(%{
         "type" => "heading_2",
         "heading_2" => %{"rich_text" => rich_text}
       }) do
    extract_text_from_rich_text(rich_text)
  end

  defp extract_text_from_block(%{
         "type" => "heading_3",
         "heading_3" => %{"rich_text" => rich_text}
       }) do
    extract_text_from_rich_text(rich_text)
  end

  defp extract_text_from_block(%{
         "type" => "bulleted_list_item",
         "bulleted_list_item" => %{"rich_text" => rich_text}
       }) do
    extract_text_from_rich_text(rich_text)
  end

  defp extract_text_from_block(%{
         "type" => "numbered_list_item",
         "numbered_list_item" => %{"rich_text" => rich_text}
       }) do
    extract_text_from_rich_text(rich_text)
  end

  defp extract_text_from_block(%{"type" => "to_do", "to_do" => %{"rich_text" => rich_text}}) do
    extract_text_from_rich_text(rich_text)
  end

  defp extract_text_from_block(%{"type" => "toggle", "toggle" => %{"rich_text" => rich_text}}) do
    extract_text_from_rich_text(rich_text)
  end

  defp extract_text_from_block(%{"type" => "quote", "quote" => %{"rich_text" => rich_text}}) do
    extract_text_from_rich_text(rich_text)
  end

  defp extract_text_from_block(%{"type" => "callout", "callout" => %{"rich_text" => rich_text}}) do
    extract_text_from_rich_text(rich_text)
  end

  defp extract_text_from_block(%{"type" => "code", "code" => %{"rich_text" => rich_text}}) do
    extract_text_from_rich_text(rich_text)
  end

  defp extract_text_from_block(_), do: nil

  # Extract text from rich_text array
  defp extract_text_from_rich_text(rich_text) when is_list(rich_text) do
    Enum.map_join(rich_text, "", fn
      %{"type" => "text", "text" => %{"content" => content}} -> content
      _ -> ""
    end)
  end

  defp extract_text_from_rich_text(_), do: ""

  # Helper functions for file handling
  defp get_file_url(%{"type" => "external", "external" => %{"url" => url}}, _), do: url
  defp get_file_url(%{"type" => "file", "file" => %{"url" => url}}, _), do: url
  defp get_file_url(_, _), do: nil

  defp determine_mimetype("image", %{"caption" => caption}) do
    # Try to determine image type from caption or default to generic image
    cond do
      caption |> String.downcase() |> String.ends_with?(".png") -> "image/png"
      caption |> String.downcase() |> String.ends_with?(".jpg") -> "image/jpeg"
      caption |> String.downcase() |> String.ends_with?(".jpeg") -> "image/jpeg"
      caption |> String.downcase() |> String.ends_with?(".gif") -> "image/gif"
      caption |> String.downcase() |> String.ends_with?(".webp") -> "image/webp"
      # Default
      true -> "image/jpeg"
    end
  end

  defp determine_mimetype("pdf", _), do: "application/pdf"

  defp determine_mimetype("file", %{"caption" => caption}) do
    # Try to determine file type from caption or default to octet-stream
    cond do
      caption |> String.downcase() |> String.ends_with?(".pdf") ->
        "application/pdf"

      caption |> String.downcase() |> String.ends_with?(".doc") ->
        "application/msword"

      caption |> String.downcase() |> String.ends_with?(".docx") ->
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

      caption |> String.downcase() |> String.ends_with?(".xls") ->
        "application/vnd.ms-excel"

      caption |> String.downcase() |> String.ends_with?(".xlsx") ->
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

      caption |> String.downcase() |> String.ends_with?(".ppt") ->
        "application/vnd.ms-powerpoint"

      caption |> String.downcase() |> String.ends_with?(".pptx") ->
        "application/vnd.openxmlformats-officedocument.presentationml.presentation"

      caption |> String.downcase() |> String.ends_with?(".txt") ->
        "text/plain"

      # Default
      true ->
        "application/octet-stream"
    end
  end

  defp determine_mimetype(_, _), do: "application/octet-stream"
end
