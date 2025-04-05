defmodule PiiGuardian.AnthropicPiiDetection do
  @moduledoc """
  Detect if a text or PDF contains PII (Personally Identifiable Information) using the Anthropic's API.
  """

  @type result :: :safe | {:unsafe, String.t()}

  @safe_response_prefix "[NO_PII_SAFE]"
  @unsafe_response_prefix "[YES_PII_UNSAFE]"

  @consistent_format_prompt "Please begin your response with '#{@unsafe_response_prefix}' or '#{@safe_response_prefix}', according with whether or not PII is detected."

  @spec detect_pii_in_text(String.t()) :: result
  def detect_pii_in_text(text) when is_binary(text) do
    client = "ANTHROPIC_API_KEY" |> System.get_env() |> Anthropix.init()

    messages = [
      %{role: "user", content: text},
      %{role: "user", content: "Does this text contain PII?"},
      %{role: "user", content: @consistent_format_prompt}
    ]

    chat_opts = [messages: messages, model: "claude-3-5-sonnet-20241022"]

    client
    |> Anthropix.chat(chat_opts)
    |> parse_response()
  end

  def detect_pii_in_pdf(pdf_file_path) do
    pdf = pdf_file_path |> File.read!() |> Base.encode64()

    client = "ANTHROPIC_API_KEY" |> System.get_env() |> Anthropix.init()

    messages = [
      %{
        role: "user",
        content: [
          %{type: "document", source: %{type: "base64", media_type: "application/pdf", data: pdf}}
        ]
      },
      %{role: "user", content: "Does this PDF contain PII?"}
    ]

    Anthropix.chat(client, messages: messages, model: "claude-3-5-sonnet-20241022")
  end

  defp parse_response({:ok, %{"content" => [%{"text" => response_text}]}}) do
    case response_text do
      @safe_response_prefix <> _ -> :safe
      @unsafe_response_prefix <> explanation -> {:unsafe, explanation}
    end
  end
end
