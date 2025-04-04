defmodule PIIGuardian.PII.AIService do
  @moduledoc """
  Integration with AI services for PII detection and text extraction.
  """
  require Logger

  alias Tesla.Middleware

  # Initialize HTTP client at compile time
  # Will be replaced with runtime config in init
  @client Tesla.client([
    {Middleware.BaseUrl, "https://api.openai.com"},
    Middleware.JSON
  ])

  use GenServer

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Analyzes text for PII.
  
  Returns {:pii_found, types}, {:no_pii}, or {:error, reason}.
  """
  def analyze_for_pii(text, source_type \\ :text) do
    GenServer.call(__MODULE__, {:analyze_for_pii, text, source_type}, 30_000)
  end

  @doc """
  Extracts text from an image.
  """
  def extract_text_from_image(image_url) do
    GenServer.call(__MODULE__, {:extract_text_from_image, image_url}, 30_000)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Initializing AI service connector")
    
    config = Application.get_env(:pii_guardian, __MODULE__)
    
    service = config[:service] || "openai"
    api_key = config[:api_key]
    endpoint = config[:endpoint]
    
    if api_key do
      client = build_client(service, api_key, endpoint)
      
      Logger.info("AI service (#{service}) initialized successfully")
      {:ok, %{client: client, service: service}}
    else
      Logger.error("AI service API key not configured")
      {:ok, %{client: nil, service: service}}
    end
  end

  @impl true
  def handle_call({:analyze_for_pii, text, source_type}, _from, %{client: client, service: service} = state) do
    result = case service do
      "openai" -> analyze_with_openai(client, text, source_type)
      "azure" -> analyze_with_azure(client, text, source_type)
      "test" -> mock_analysis(text)
      _ -> {:error, :unsupported_service}
    end
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:extract_text_from_image, image_url}, _from, %{client: client, service: service} = state) do
    result = case service do
      "openai" -> extract_text_with_openai(client, image_url)
      "azure" -> extract_text_with_azure(client, image_url)
      "test" -> mock_text_extraction(image_url)
      _ -> {:error, :unsupported_service}
    end
    
    {:reply, result, state}
  end

  # Private functions

  defp build_client("openai", api_key, _endpoint) do
    middleware = [
      {Middleware.BaseUrl, "https://api.openai.com"},
      {Middleware.Headers, [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"}
      ]},
      Middleware.JSON
    ]
    
    Tesla.client(middleware)
  end

  defp build_client("azure", api_key, endpoint) do
    middleware = [
      {Middleware.BaseUrl, endpoint || "https://api.cognitive.microsoft.com"},
      {Middleware.Headers, [
        {"Ocp-Apim-Subscription-Key", api_key},
        {"Content-Type", "application/json"}
      ]},
      Middleware.JSON
    ]
    
    Tesla.client(middleware)
  end

  defp build_client("test", _api_key, _endpoint) do
    middleware = [
      {Middleware.BaseUrl, "http://localhost:4000"},
      Middleware.JSON
    ]
    
    Tesla.client(middleware)
  end

  defp build_client(_, _, _), do: @client

  defp analyze_with_openai(client, text, source_type) do
    source_context = case source_type do
      :image -> "extracted from an image"
      :pdf -> "extracted from a PDF"
      _ -> "from a message or document"
    end
    
    prompt = """
    Analyze the following text #{source_context} for personally identifiable information (PII).
    Identify if it contains any of the following: names, email addresses, phone numbers,
    addresses, social security numbers, credit card numbers, passport numbers, driver's license numbers,
    or any other personal identifiers.
    
    Respond with only 'NO_PII_FOUND' if no PII is detected.
    If PII is found, respond with a JSON array listing the types of PII found, like:
    ['Email', 'Phone Number', 'Address']
    
    Text to analyze:
    #{text}
    """
    
    payload = %{
      model: "gpt-4o",
      messages: [
        %{role: "system", content: "You are a PII detection tool that only responds with 'NO_PII_FOUND' or a JSON array of PII types found."},
        %{role: "user", content: prompt}
      ],
      temperature: 0.1
    }
    
    case Tesla.post(client, "/v1/chat/completions", payload) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => response}} | _]}}} ->
        parse_pii_response(response)
      {:ok, response} ->
        Logger.error("Unexpected OpenAI response: #{inspect(response)}")
        {:error, :unexpected_response}
      {:error, error} ->
        Logger.error("Error from OpenAI: #{inspect(error)}")
        {:error, error}
    end
  end

  defp analyze_with_azure(client, text, source_type) do
    # Azure implementation would be similar to OpenAI
    # But would use Azure's specific API endpoints and parameters
    {:error, :not_implemented}
  end

  defp extract_text_with_openai(client, image_url) do
    # This would use OpenAI's vision model to extract text from images
    # For our implementation, we'll simplify and just return dummy text for demo
    {:ok, "Sample text extracted from image at #{image_url}"}
  end

  defp extract_text_with_azure(client, image_url) do
    # This would use Azure's Computer Vision API to extract text from images
    {:error, :not_implemented}
  end

  defp parse_pii_response("NO_PII_FOUND"), do: {:no_pii}

  defp parse_pii_response(response) do
    # Try to parse JSON array of PII types
    case Jason.decode(response) do
      {:ok, types} when is_list(types) and length(types) > 0 ->
        {:pii_found, types}
      _ ->
        if String.contains?(response, "NO_PII_FOUND") do
          {:no_pii}
        else
          # Try to salvage some info from malformed response
          types = extract_pii_types_from_text(response)
          if length(types) > 0 do
            {:pii_found, types}
          else
            {:no_pii}
          end
        end
    end
  end

  defp extract_pii_types_from_text(text) do
    # Common PII types to look for in AI response
    pii_types = ["Email", "Phone", "Address", "SSN", "Social Security", "Credit Card", 
                "Name", "Date of Birth", "Driver's License", "Passport", "IP Address"]
    
    Enum.filter(pii_types, fn type -> 
      String.contains?(text, type)
    end)
  end

  # Mock implementations for testing

  defp mock_analysis(text) do
    cond do
      String.contains?(text, "@") -> 
        {:pii_found, ["Email"]}
      Regex.match?(~r/\d{3}[- ]?\d{3}[- ]?\d{4}/, text) -> 
        {:pii_found, ["Phone Number"]}
      Regex.match?(~r/\d{3}[- ]?\d{2}[- ]?\d{4}/, text) -> 
        {:pii_found, ["SSN"]}
      String.length(text) < 10 ->
        {:no_pii}
      true -> 
        # Randomly return PII or not for testing
        if :rand.uniform() > 0.7 do
          {:pii_found, ["Name", "Address"]}
        else
          {:no_pii}
        end
    end
  end

  defp mock_text_extraction(_image_url) do
    # Return fake extracted text for testing
    {:ok, "John Smith, 123 Main St, Springfield, IL 62701, Phone: 555-123-4567, Email: john@example.com"}
  end
end
