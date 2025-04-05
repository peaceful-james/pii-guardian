defmodule PiiGuardian.SlackPiiDetection do
  @moduledoc """
  Detect if a Slack event contains PII (Personally Identifiable Information).
  """
  alias PiiGuardian.AnthropicPiiDetection
  alias PiiGuardian.SlackApi

  require Logger

  @doc """
  Detects if a Slack event contains PII (Personally Identifiable Information).
  """
  def detect_pii_in_text(%{"type" => "message", "text" => text}) do
    AnthropicPiiDetection.detect_pii_in_text(text)
  end

  def detect_pii_in_file(%{"id" => file_id, "url_private_download" => url_private_download}) do
    Logger.debug("Retrieving file info for file ID: #{file_id}")

    with {:ok, %Tesla.Env{body: raw_body}} <- SlackApi.download_file(url_private_download),
         {:ok, %{"file" => %{"filetype" => filetype, "mimetype" => mimetype}} = result} <-
           SlackApi.get_file_info(file_id) do
      Logger.debug(
        "File content retrieved successfully for file ID #{file_id}: #{inspect(result, pretty: true)}"
      )

      AnthropicPiiDetection.detect_pii_in_file(raw_body, filetype, mimetype)
    else
      {:error, _reason} ->
        Logger.error("Failed to retrieve file info for file ID: #{file_id}")
        {:unsafe, "Failed to retrieve file info"}
    end
  end
end
