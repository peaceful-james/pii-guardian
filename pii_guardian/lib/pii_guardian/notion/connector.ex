defmodule PIIGuardian.Notion.Connector do
  @moduledoc """
  Handles Notion API authentication and connections.
  """
  use GenServer
  require Logger

  alias Tesla.Middleware

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a page by its ID.
  """
  def get_page(page_id) do
    GenServer.call(__MODULE__, {:get_page, page_id})
  end

  @doc """
  Gets a database by its ID.
  """
  def get_database(database_id) do
    GenServer.call(__MODULE__, {:get_database, database_id})
  end

  @doc """
  Queries a database for pages.
  """
  def query_database(database_id, filter \\ nil, sorts \\ nil) do
    GenServer.call(__MODULE__, {:query_database, database_id, filter, sorts})
  end

  @doc """
  Deletes a page (archives it in Notion).
  """
  def delete_page(page_id) do
    GenServer.call(__MODULE__, {:delete_page, page_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Initializing Notion connector")
    
    api_key = Application.get_env(:pii_guardian, PIIGuardian.Notion)[:api_key]
    
    if api_key do
      # Initialize the client
      client = build_client(api_key)
      
      Logger.info("Notion connector initialized successfully")
      {:ok, %{client: client}}
    else
      Logger.error("Notion API key not configured")
      {:ok, %{client: nil}}
    end
  end

  @impl true
  def handle_call({:get_page, page_id}, _from, %{client: client} = state) do
    response = Tesla.get(client, "/v1/pages/#{page_id}")
    
    result = case response do
      {:ok, %{status: 200, body: body}} -> 
        {:ok, body}
      {:ok, %{status: status, body: body}} -> 
        Logger.error("Failed to get page: #{status} - #{inspect(body)}")
        {:error, body}
      {:error, error} -> 
        Logger.error("Failed to get page: #{inspect(error)}")
        {:error, error}
    end
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_database, database_id}, _from, %{client: client} = state) do
    response = Tesla.get(client, "/v1/databases/#{database_id}")
    
    result = case response do
      {:ok, %{status: 200, body: body}} -> 
        {:ok, body}
      {:ok, %{status: status, body: body}} -> 
        Logger.error("Failed to get database: #{status} - #{inspect(body)}")
        {:error, body}
      {:error, error} -> 
        Logger.error("Failed to get database: #{inspect(error)}")
        {:error, error}
    end
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:query_database, database_id, filter, sorts}, _from, %{client: client} = state) do
    payload = build_query_payload(filter, sorts)
    
    response = Tesla.post(client, "/v1/databases/#{database_id}/query", payload)
    
    result = case response do
      {:ok, %{status: 200, body: body}} -> 
        {:ok, body}
      {:ok, %{status: status, body: body}} -> 
        Logger.error("Failed to query database: #{status} - #{inspect(body)}")
        {:error, body}
      {:error, error} -> 
        Logger.error("Failed to query database: #{inspect(error)}")
        {:error, error}
    end
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:delete_page, page_id}, _from, %{client: client} = state) do
    # In Notion, we archive pages rather than delete them
    payload = %{archived: true}
    
    response = Tesla.patch(client, "/v1/pages/#{page_id}", payload)
    
    result = case response do
      {:ok, %{status: 200, body: body}} -> 
        Logger.info("Successfully archived Notion page #{page_id}")
        {:ok, body}
      {:ok, %{status: status, body: body}} -> 
        Logger.error("Failed to archive page: #{status} - #{inspect(body)}")
        {:error, body}
      {:error, error} -> 
        Logger.error("Failed to archive page: #{inspect(error)}")
        {:error, error}
    end
    
    {:reply, result, state}
  end

  # Private functions

  defp build_client(api_key) do
    middleware = [
      {Middleware.BaseUrl, "https://api.notion.com"},
      {Middleware.Headers, [
        {"Authorization", "Bearer #{api_key}"},
        {"Notion-Version", "2022-06-28"},
        {"Content-Type", "application/json"}
      ]},
      Middleware.JSON
    ]
    
    Tesla.client(middleware)
  end

  defp build_query_payload(filter, sorts) do
    payload = %{}
    
    payload = if filter, do: Map.put(payload, :filter, filter), else: payload
    payload = if sorts, do: Map.put(payload, :sorts, sorts), else: payload
    
    payload
  end
end
