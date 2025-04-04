defmodule PIIGuardian.PII.ImageDetector do
  @moduledoc """
  Analyzes images for PII using OCR and AI analysis.
  """
  require Logger

  alias PIIGuardian.PII.AIService
  alias PIIGuardian.PII.TextDetector

  @doc """
  Detects PII in an image file.
  
  Returns either {:pii_found, details} or {:no_pii}.
  """
  def detect_pii(image_file) when is_map(image_file) do
    Logger.debug("Analyzing image for PII: #{image_file[:name] || image_file[:url] || "unknown"}")
    
    with {:ok, image_url} <- extract_url(image_file),
         {:ok, text} <- extract_text_from_image(image_url) do
      
      # Now that we have extracted text, analyze it for PII
      case AIService.analyze_for_pii(text, :image) do
        {:pii_found, types} ->
          Logger.info("PII found in image: #{inspect(types)}")
          {:pii_found, %{types: types}}
        
        {:no_pii} ->
          # Fallback to regex detection as a safety measure
          case TextDetector.detect_pii_with_regex(text) do
            {:pii_found, details} -> 
              Logger.info("PII found in image via regex: #{inspect(details.types)}")
              {:pii_found, details}
            _ -> 
              {:no_pii}
          end
        
        {:error, reason} ->
          Logger.error("Error detecting PII in image text: #{inspect(reason)}")
          {:no_pii}  # Default to no PII on error for safety
      end
    else
      {:error, reason} ->
        Logger.error("Error processing image: #{inspect(reason)}")
        {:no_pii}  # Default to no PII on error for safety
    end
  end

  def detect_pii(_), do: {:no_pii}

  # Private functions

  defp extract_url(%{url: url}) when is_binary(url), do: {:ok, url}
  defp extract_url(%{"url" => url}) when is_binary(url), do: {:ok, url}
  defp extract_url(_), do: {:error, :no_url}

  defp extract_text_from_image(image_url) do
    Logger.debug("Extracting text from image: #{image_url}")
    
    # In a real implementation, we would use an OCR service here
    # For this implementation, we'll simulate OCR by sending the image URL to our AI service
    case AIService.extract_text_from_image(image_url) do
      {:ok, text} -> 
        Logger.debug("Successfully extracted text from image")
        {:ok, text}
      {:error, reason} -> 
        Logger.error("Failed to extract text from image: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
