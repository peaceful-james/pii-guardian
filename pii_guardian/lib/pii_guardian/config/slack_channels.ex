defmodule PIIGuardian.Config.SlackChannels do
  @moduledoc """
  Manages the list of watched Slack channels.
  """
  use GenServer
  require Logger

  @table_name :watched_slack_channels

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the list of Slack channels being watched.
  """
  def list_channels do
    GenServer.call(__MODULE__, :list_channels)
  end

  @doc """
  Adds a channel to the watch list.
  """
  def add_channel(channel_id) do
    GenServer.call(__MODULE__, {:add_channel, channel_id})
  end

  @doc """
  Removes a channel from the watch list.
  """
  def remove_channel(channel_id) do
    GenServer.call(__MODULE__, {:remove_channel, channel_id})
  end

  @doc """
  Checks if a channel is being watched.
  """
  def watching?(channel_id) do
    GenServer.call(__MODULE__, {:watching?, channel_id})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Initializing Slack channels watch list")
    :ets.new(@table_name, [:set, :protected, :named_table])
    
    # Initialize with channels from config
    channels = Application.get_env(:pii_guardian, PIIGuardian.Slack)[:watched_channels] || []
    
    Enum.each(channels, fn channel_id ->
      :ets.insert(@table_name, {channel_id, true})
    end)
    
    {:ok, %{channels: channels}}
  end

  @impl true
  def handle_call(:list_channels, _from, state) do
    channels = :ets.tab2list(@table_name) |> Enum.map(fn {channel_id, _} -> channel_id end)
    {:reply, channels, state}
  end

  @impl true
  def handle_call({:add_channel, channel_id}, _from, state) do
    :ets.insert(@table_name, {channel_id, true})
    Logger.info("Added channel to watch list: #{channel_id}")
    channels = [channel_id | state.channels] |> Enum.uniq()
    {:reply, :ok, %{state | channels: channels}}
  end

  @impl true
  def handle_call({:remove_channel, channel_id}, _from, state) do
    :ets.delete(@table_name, channel_id)
    Logger.info("Removed channel from watch list: #{channel_id}")
    channels = state.channels -- [channel_id]
    {:reply, :ok, %{state | channels: channels}}
  end

  @impl true
  def handle_call({:watching?, channel_id}, _from, state) do
    result = case :ets.lookup(@table_name, channel_id) do
      [{^channel_id, true}] -> true
      _ -> false
    end
    {:reply, result, state}
  end
end
