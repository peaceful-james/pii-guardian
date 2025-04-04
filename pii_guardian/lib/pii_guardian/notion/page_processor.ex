defmodule PIIGuardian.Notion.PageProcessor do
  @moduledoc """
  Processes Notion pages for PII content.
  """
  require Logger

  alias PIIGuardian.PII.Analyzer
  alias PIIGuardian.Notion.Actions
  alias PIIGuardian.PubSub

  @doc """
  Processes a Notion page, checking for PII.
  
  If PII is found, the page is deleted and the author is notified via Slack.
  """
  def process_page(page, database_id) do
    page_id = page["id"]
    Logger.debug("Processing Notion page #{page_id} from database #{database_id}")
    
    # Extract content and metadata
    content = extract_content(page)
    author = get_page_author(page)
    
    # Check for PII in the content
    case Analyzer.analyze_content(content) do
      {:pii_found, pii_details} ->
        # PII was found, delete the page and notify author
        Logger.info("PII found in Notion page #{page_id} created by #{author}")
        
        # Delete the page
        Actions.delete_page(page_id)
        
        # Notify the author
        page_title = get_page_title(page)
        Actions.notify_author(author, page_title, content, pii_details)
        
        # Broadcast event
        PubSub.broadcast("pii:detected", {:pii_detected, :notion, author, pii_details})
        
      {:no_pii} ->
        # No PII found, do nothing
        Logger.debug("No PII found in page #{page_id}")
    end
  end

  # Private functions

  defp extract_content(page) do
    # Extract text from title
    title = get_page_title(page)
    
    # Extract all properties
    properties = extract_properties(page["properties"])
    
    # Extract file attachments
    files = extract_files(page)
    
    %{
      title: title,
      properties: properties,
      files: files
    }
  end

  defp get_page_title(page) do
    # Find the title property
    title_prop = Enum.find(page["properties"] || %{}, fn {_key, prop} -> 
      prop["type"] == "title"
    end)
    
    case title_prop do
      {_, %{"title" => title_parts}} ->
        title_parts
        |> Enum.map(fn part -> part["plain_text"] end)
        |> Enum.join("")
      _ ->
        "Untitled"
    end
  end

  defp extract_properties(properties) do
    Enum.flat_map(properties || %{}, fn {name, property} ->
      extract_property_value(name, property)
    end)
  end

  defp extract_property_value(name, %{"type" => "rich_text", "rich_text" => text_parts}) do
    text = text_parts
          |> Enum.map(fn part -> part["plain_text"] end)
          |> Enum.join("")
    
    [{name, text}]
  end

  defp extract_property_value(name, %{"type" => "title", "title" => text_parts}) do
    text = text_parts
          |> Enum.map(fn part -> part["plain_text"] end)
          |> Enum.join("")
    
    [{name, text}]
  end

  defp extract_property_value(name, %{"type" => "number", "number" => number}) when not is_nil(number) do
    [{name, to_string(number)}]
  end

  defp extract_property_value(name, %{"type" => "select", "select" => %{"name" => value}}) when not is_nil(value) do
    [{name, value}]
  end

  defp extract_property_value(name, %{"type" => "multi_select", "multi_select" => values}) do
    text = values
          |> Enum.map(fn value -> value["name"] end)
          |> Enum.join(", ")
    
    [{name, text}]
  end

  defp extract_property_value(name, %{"type" => "date", "date" => %{"start" => start}}) when not is_nil(start) do
    [{name, start}]
  end

  defp extract_property_value(name, %{"type" => "email", "email" => email}) when not is_nil(email) do
    [{name, email}]
  end

  defp extract_property_value(name, %{"type" => "phone_number", "phone_number" => phone}) when not is_nil(phone) do
    [{name, phone}]
  end

  defp extract_property_value(name, %{"type" => "url", "url" => url}) when not is_nil(url) do
    [{name, url}]
  end

  defp extract_property_value(_name, _property) do
    # Skip properties we can't extract text from
    []
  end

  defp extract_files(page) do
    # Find all file properties
    file_props = Enum.filter(page["properties"] || %{}, fn {_key, prop} -> 
      prop["type"] == "files"
    end)
    
    Enum.flat_map(file_props, fn {_name, %{"files" => files}} ->
      Enum.map(files, fn file ->
        case file["type"] do
          "external" -> %{url: file["external"]["url"], name: file["name"]}
          "file" -> %{url: file["file"]["url"], name: file["name"]}
          _ -> nil
        end
      end)
      |> Enum.filter(&(&1 != nil))
    end)
  end

  defp get_page_author(page) do
    # Get the creator's email (for mapping to Slack)
    case page["created_by"] do
      %{"id" => user_id} ->
        # In a real implementation, we would make an API call to get the user's email
        # For now, we'll use the user ID as a placeholder
        user_id
      _ ->
        "unknown"
    end
  end
end
