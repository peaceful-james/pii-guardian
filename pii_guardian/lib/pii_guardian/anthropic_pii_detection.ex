defmodule PiiGuardian.AnthropicPiiDetection do
  @moduledoc """
  Detect if a text or PDF contains PII (Personally Identifiable Information) using the Anthropic's API.
  """
  # Implement the behaviour for mocking in tests
  @behaviour PiiGuardian.AnthropicPiiDetectionBehaviour

  # Use dependency injection in test environment

  require Logger

  @type result :: :safe | {:unsafe, String.t()}

  @safe_response_prefix "[NO_PII_SAFE]"
  @unsafe_response_prefix "[YES_PII_UNSAFE]"

  @consistent_format_prompt "Please begin your response with '#{@unsafe_response_prefix}' or '#{@safe_response_prefix}', according with whether or not PII is detected."

  defp api_key do
    Application.fetch_env!(:pii_guardian, :anthropic_api_key)
  end

  defp init_client do
    anthropix().init(api_key())
  end

  # Helper function to get the appropriate module
  defp anthropix do
    Application.get_env(:pii_guardian, :anthropix)
  end

  @spec detect_pii_in_text(String.t() | nil) :: result
  def detect_pii_in_text(nil), do: :safe
  def detect_pii_in_text(""), do: :safe

  def detect_pii_in_text(text) when is_binary(text) do
    messages = [
      %{role: "user", content: text},
      %{role: "user", content: "Does this text contain PII?"},
      %{role: "user", content: @consistent_format_prompt}
    ]

    chat_opts = [messages: messages, model: "claude-3-5-sonnet-20241022"]

    client = init_client()

    client
    |> anthropix().chat(chat_opts)
    |> tap(&Logger.debug("Anthropic API response for text: #{inspect(&1, pretty: true)}"))
    |> parse_response()
  end

  def detect_pii_in_file(content, "text", _mimetype) do
    detect_pii_in_text(content)
  end

  def detect_pii_in_file(content, _filetype, mimetype) do
    source = %{type: "base64", media_type: mimetype, data: Base.encode64(content)}

    type =
      if String.starts_with?(mimetype, "image/") do
        "image"
      else
        "document"
      end

    content =
      %{type: type, source: source}

    messages = [
      %{role: "user", content: [content]},
      %{role: "user", content: "Does this file contain PII?"},
      %{role: "user", content: @consistent_format_prompt}
    ]

    chat_opts = [messages: messages, model: "claude-3-5-sonnet-20241022"]

    client = init_client()

    client
    |> anthropix().chat(chat_opts)
    |> tap(&Logger.debug("Anthropic API response for file: #{inspect(&1, pretty: true)}"))
    |> parse_response()
  end

  defp parse_response({:ok, %{"content" => [%{"text" => response_text}]}}) do
    case response_text do
      @safe_response_prefix <> _ -> :safe
      @unsafe_response_prefix <> explanation -> {:unsafe, String.trim(explanation)}
    end
  end
end
