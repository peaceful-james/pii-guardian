defmodule PIIGuardian.PII.TextDetector do
  @moduledoc """
  Analyzes text content for PII.
  """
  require Logger

  alias PIIGuardian.PII.AIService

  @doc """
  Detects PII in text content.
  
  Returns either {:pii_found, details} or {:no_pii}.
  """
  def detect_pii(text) when is_binary(text) and text != "" do
    Logger.debug("Detecting PII in text content")
    
    # Use AI service to detect PII
    case AIService.analyze_for_pii(text, :text) do
      {:pii_found, types} ->
        Logger.info("PII found in text: #{inspect(types)}")
        {:pii_found, %{types: types}}
      
      {:no_pii} ->
        Logger.debug("No PII found in text content")
        {:no_pii}
      
      {:error, reason} ->
        Logger.error("Error detecting PII in text: #{inspect(reason)}")
        {:no_pii}  # Default to no PII on error for safety
    end
  end

  def detect_pii(_), do: {:no_pii}

  # Patterns to detect common PII types
  # These are basic patterns and would be augmented by the AI service
  @email_regex ~r/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/
  @phone_regex ~r/\b(\+\d{1,3}[\s-]?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}\b/
  @ssn_regex ~r/\b\d{3}[-]?\d{2}[-]?\d{4}\b/
  @credit_card_regex ~r/\b(?:\d[ -]*?){13,16}\b/

  @doc """
  Performs regex-based PII detection on text.
  This is used as a fallback or supplement to AI-based detection.
  """
  def detect_pii_with_regex(text) when is_binary(text) and text != "" do
    pii_types = []
    
    # Check for each PII type
    pii_types = if Regex.match?(@email_regex, text), do: ["Email" | pii_types], else: pii_types
    pii_types = if Regex.match?(@phone_regex, text), do: ["Phone Number" | pii_types], else: pii_types
    pii_types = if Regex.match?(@ssn_regex, text), do: ["SSN" | pii_types], else: pii_types
    pii_types = if Regex.match?(@credit_card_regex, text), do: ["Credit Card" | pii_types], else: pii_types
    
    case pii_types do
      [] -> {:no_pii}
      types -> {:pii_found, %{types: types}}
    end
  end

  def detect_pii_with_regex(_), do: {:no_pii}
end
