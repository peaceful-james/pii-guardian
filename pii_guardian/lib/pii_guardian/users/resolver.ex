defmodule PIIGuardian.Users.Resolver do
  @moduledoc """
  Maps between Notion users and Slack users.
  """
  use GenServer
  require Logger

  @table_name :user_mappings

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the Slack user ID for a Notion user.
  
  ## Parameters
    - notion_user: Can be either a user ID or email
  
  ## Returns
    - {:ok, slack_user_id} if found
    - {:error, reason} if not found
  """
  def get_slack_user_for_notion_user(notion_user) do
    GenServer.call(__MODULE__, {:get_slack_user, notion_user})
  end

  @doc """
  Adds a mapping between a Notion user and a Slack user.
  
  ## Parameters
    - notion_user: The Notion user ID or email
    - slack_user_id: The Slack user ID
  """
  def add_mapping(notion_user, slack_user_id) do
    GenServer.call(__MODULE__, {:add_mapping, notion_user, slack_user_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Initializing User Resolver")
    :ets.new(@table_name, [:set, :protected, :named_table])
    
    # In a real implementation, we would initialize with mappings from a database
    # For this sample, we'll use some test mappings
    add_test_mappings()
    
    {:ok, %{}}
  end

  @impl true
  def handle_call({:get_slack_user, notion_user}, _from, state) do
    # Try to find by user ID or email
    result = case :ets.lookup(@table_name, notion_user) do
      [{^notion_user, slack_user_id}] -> 
        {:ok, slack_user_id}
      
      [] -> 
        # Try to find by email lookup in Slack
        case lookup_slack_user_by_email(notion_user) do
          {:ok, slack_user_id} -> 
            # Cache the mapping for future use
            :ets.insert(@table_name, {notion_user, slack_user_id})
            {:ok, slack_user_id}
            
          {:error, reason} -> 
            {:error, reason}
        end
    end
    
    {:reply, result, state}
  end

  @impl true
  def handle_call({:add_mapping, notion_user, slack_user_id}, _from, state) do
    :ets.insert(@table_name, {notion_user, slack_user_id})
    Logger.info("Added user mapping: Notion #{notion_user} -> Slack #{slack_user_id}")
    {:reply, :ok, state}
  end

  # Private functions

  defp lookup_slack_user_by_email(email) when is_binary(email) do
    # In a real implementation, we would use the Slack API to look up a user by email
    # For this sample, we'll simulate the lookup
    Logger.debug("Looking up Slack user by email: #{email}")
    
    # Simulate API call
    case email do
      "test@example.com" -> {:ok, "U12345678"}
      email when is_binary(email) -> 
        # For testing, generate a deterministic user ID based on the email
        {:ok, "U" <> (email |> :erlang.md5 |> Base.encode16 |> binary_part(0, 8))}
      _ -> {:error, :not_found}
    end
  end

  defp lookup_slack_user_by_email(_), do: {:error, :invalid_email}

  defp add_test_mappings do
    # Add some test mappings for development/testing
    :ets.insert(@table_name, {"notion_user_1", "U12345678"})
    :ets.insert(@table_name, {"notion_user_2", "U87654321"})
    :ets.insert(@table_name, {"test@example.com", "U12345678"})
  end
end