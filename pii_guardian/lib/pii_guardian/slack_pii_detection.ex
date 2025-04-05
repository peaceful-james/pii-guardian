defmodule PiiGuardian.SlackPiiDetection do
  @moduledoc """
  Detect if a Slack event contains PII (Personally Identifiable Information).
  """
  alias PiiGuardian.AnthropicPiiDetection
  alias PiiGuardian.Slackbot

  @doc """
  Detects if a Slack event contains PII (Personally Identifiable Information).
  """
  def detect_pii_in_text(%{"type" => "message", "text" => text}) do
    AnthropicPiiDetection.detect_pii_in_text(text)
  end

  def detect_pii_in_file(%{"url_private" => url_private}) do
    url_private
    |> Slackbot.read_file!()
    |> AnthropicPiiDetection.detect_pii_in_pdf()
  end
end
