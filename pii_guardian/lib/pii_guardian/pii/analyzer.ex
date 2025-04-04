defmodule PIIGuardian.PII.Analyzer do
  @moduledoc """
  Coordinates PII analysis using multiple detectors for different content types.
  """
  require Logger

  alias PIIGuardian.PII.TextDetector
  alias PIIGuardian.PII.ImageDetector
  alias PIIGuardian.PII.PDFDetector

  @doc """
  Analyzes content for PII information.
  
  Returns either {:pii_found, details} or {:no_pii}.
  """
  def analyze_content(content) do
    Logger.debug("Analyzing content for PII")
    
    # Run each detector and collect results
    text_result = analyze_text(content)
    image_result = analyze_images(content)
    file_result = analyze_files(content)
    
    # Combine results from all detectors
    combine_results([text_result, image_result, file_result])
  end

  # Private functions

  defp analyze_text(content) do
    Logger.debug("Analyzing text content for PII")
    
    # Extract all text content
    text_content = extract_text_content(content)
    
    # Analyze text for PII
    TextDetector.detect_pii(text_content)
  end

  defp analyze_images(content) do
    Logger.debug("Analyzing image content for PII")
    
    # Extract image files
    image_files = extract_image_files(content)
    
    # Analyze each image for PII
    image_files
    |> Enum.map(&ImageDetector.detect_pii/1)
    |> combine_results()
  end

  defp analyze_files(content) do
    Logger.debug("Analyzing file attachments for PII")
    
    # Extract PDF files
    pdf_files = extract_pdf_files(content)
    
    # Analyze each PDF for PII
    pdf_files
    |> Enum.map(&PDFDetector.detect_pii/1)
    |> combine_results()
  end

  defp extract_text_content(%{text: text}) when is_binary(text) do
    text
  end

  defp extract_text_content(%{title: title, properties: properties}) do
    # Extract text from properties and combine with title
    property_text = properties
                   |> Enum.map(fn {_name, value} -> value end)
                   |> Enum.join(" ")
    
    "#{title} #{property_text}"
  end

  defp extract_text_content(content) when is_map(content) do
    # Try to extract from any text fields
    content
    |> Map.values()
    |> Enum.map(fn
      value when is_binary(value) -> value
      value when is_list(value) -> extract_text_from_list(value)
      _ -> ""
    end)
    |> Enum.join(" ")
  end

  defp extract_text_content(_), do: ""

  defp extract_text_from_list(list) do
    list
    |> Enum.map(fn
      value when is_binary(value) -> value
      %{text: text} when is_binary(text) -> text
      %{"text" => text} when is_binary(text) -> text
      _ -> ""
    end)
    |> Enum.join(" ")
  end

  defp extract_image_files(%{files: files}) when is_list(files) do
    files
    |> Enum.filter(fn
      %{mimetype: mimetype} -> String.starts_with?(mimetype, "image/")
      %{"mimetype" => mimetype} -> String.starts_with?(mimetype, "image/")
      _ -> false
    end)
  end

  defp extract_image_files(_), do: []

  defp extract_pdf_files(%{files: files}) when is_list(files) do
    files
    |> Enum.filter(fn
      %{mimetype: mimetype} -> mimetype == "application/pdf"
      %{"mimetype" => mimetype} -> mimetype == "application/pdf"
      _ -> false
    end)
  end

  defp extract_pdf_files(_), do: []

  defp combine_results(results) do
    # Filter out nil and no_pii results
    pii_results = results
                 |> Enum.filter(fn
                   {:pii_found, _} -> true
                   _ -> false
                 end)
    
    case pii_results do
      [] ->
        # No PII found
        {:no_pii}
      
      found_results ->
        # Combine PII details from all results
        details = %{
          types: found_results
                |> Enum.flat_map(fn {:pii_found, details} -> details.types end)
                |> Enum.uniq()
        }
        
        {:pii_found, details}
    end
  end
end
