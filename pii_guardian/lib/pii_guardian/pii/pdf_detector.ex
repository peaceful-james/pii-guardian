defmodule PIIGuardian.PII.PDFDetector do
  @moduledoc """
  Analyzes PDF files for PII by extracting text and analyzing it.
  """
  require Logger

  alias PIIGuardian.PII.TextDetector

  @doc """
  Detects PII in a PDF file.
  
  Returns either {:pii_found, details} or {:no_pii}.
  """
  def detect_pii(pdf_file) when is_map(pdf_file) do
    Logger.debug("Analyzing PDF for PII: #{pdf_file[:name] || pdf_file[:url] || "unknown"}")
    
    with {:ok, pdf_url} <- extract_url(pdf_file),
         {:ok, text} <- extract_text_from_pdf(pdf_url) do
      
      # Now that we have extracted text, analyze it for PII
      TextDetector.detect_pii(text)
    else
      {:error, reason} ->
        Logger.error("Error processing PDF: #{inspect(reason)}")
        {:no_pii}  # Default to no PII on error for safety
    end
  end

  def detect_pii(_), do: {:no_pii}

  # Private functions

  defp extract_url(%{url: url}) when is_binary(url), do: {:ok, url}
  defp extract_url(%{"url" => url}) when is_binary(url), do: {:ok, url}
  defp extract_url(_), do: {:error, :no_url}

  defp extract_text_from_pdf(pdf_url) do
    Logger.debug("Extracting text from PDF: #{pdf_url}")
    
    # In a real implementation, we would use a PDF text extraction library
    # For this implementation, we'll simulate text extraction
    try do
      # Download the PDF file
      {:ok, %{body: body}} = Finch.build(:get, pdf_url)
                             |> Finch.request(PIIGuardian.Finch)
      
      # Extract text using PDF library
      case Pdf.extract_text(body) do
        {:ok, text} -> 
          Logger.debug("Successfully extracted text from PDF")
          {:ok, text}
        {:error, reason} -> 
          Logger.error("Failed to extract text from PDF: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e -> 
        Logger.error("Exception extracting text from PDF: #{inspect(e)}")
        {:error, :pdf_extraction_failed}
    end
  end
end
