defmodule PiiGuardian.SlackPiiDetection do
  @moduledoc """
  Detect if a Slack event contains PII (Personally Identifiable Information).
  """
  alias PiiGuardian.AnthropicPiiDetection
  alias PiiGuardian.SlackApi
  alias PiiGuardian.Slackbot

  @doc """
  Detects if a Slack event contains PII (Personally Identifiable Information).
  """
  def detect_pii_in_text(%{"type" => "message", "text" => text}) do
    AnthropicPiiDetection.detect_pii_in_text(text)
  end

  def detect_pii_in_file(%{"id" => file_id}) do
    case SlackApi.get_file_info(file_id) do
      {:ok, %{"content" => content, "file" => %{"filetype" => filetype, "mimetype" => mimetype}}} ->
        AnthropicPiiDetection.detect_pii_in_file(content, filetype, mimetype)

      {:error, reason} ->
        {:unsafe, "Failed to retrieve file info"}
    end
  end
end
