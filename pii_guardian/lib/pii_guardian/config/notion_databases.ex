defmodule PIIGuardian.Config.NotionDatabases do
  @moduledoc """
  Manages the list of watched Notion databases.
  """
  use GenServer
  require Logger

  @table_name :watched_notion_databases

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the list of Notion databases being watched.
  """
  def list_databases do
    GenServer.call(__MODULE__, :list_databases)
  end

  @doc """
  Adds a database to the watch list.
  """
  def add_database(database_id) do
    GenServer.call(__MODULE__, {:add_database, database_id})
  end

  @doc """
  Removes a database from the watch list.
  """
  def remove_database(database_id) do
    GenServer.call(__MODULE__, {:remove_database, database_id})
  end

  @doc """
  Checks if a database is being watched.
  """
  def watching?(database_id) do
    GenServer.call(__MODULE__, {:watching?, database_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Initializing Notion databases watch list")
    :ets.new(@table_name, [:set, :protected, :named_table])
    
    # Initialize with databases from config
    databases = Application.get_env(:pii_guardian, PIIGuardian.Notion)[:watched_databases] || []
    
    Enum.each(databases, fn database_id ->
      :ets.insert(@table_name, {database_id, true})
    end)
    
    {:ok, %{databases: databases}}
  end

  @impl true
  def handle_call(:list_databases, _from, state) do
    databases = :ets.tab2list(@table_name) |> Enum.map(fn {database_id, _} -> database_id end)
    {:reply, databases, state}
  end

  @impl true
  def handle_call({:add_database, database_id}, _from, state) do
    :ets.insert(@table_name, {database_id, true})
    Logger.info("Added database to watch list: #{database_id}")
    databases = [database_id | state.databases] |> Enum.uniq()
    {:reply, :ok, %{state | databases: databases}}
  end

  @impl true
  def handle_call({:remove_database, database_id}, _from, state) do
    :ets.delete(@table_name, database_id)
    Logger.info("Removed database from watch list: #{database_id}")
    databases = state.databases -- [database_id]
    {:reply, :ok, %{state | databases: databases}}
  end

  @impl true
  def handle_call({:watching?, database_id}, _from, state) do
    result = case :ets.lookup(@table_name, database_id) do
      [{^database_id, true}] -> true
      _ -> false
    end
    {:reply, result, state}
  end
end
