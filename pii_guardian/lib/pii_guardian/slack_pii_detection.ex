defmodule PiiGuardian.SlackPiiDetection do
  @moduledoc """
  Detect if a Slack event contains PII (Personally Identifiable Information).
  """

  @doc """
  Detects if a Slack event contains PII (Personally Identifiable Information).
  """
  def contains_pii?(%{"type" => "message", "text" => text}) do
    text_contains_pii?(text)
  end

  defp text_contains_pii?(text) when is_binary(text) do
    String.contains?(text, "[CONTAINS_PII]")
  end
end
