defmodule PIIGuardian.PubSub do
  @moduledoc """
  PubSub system for PIIGuardian.
  
  Provides a centralized event bus for communication between components.
  """
  
  @doc """
  Broadcasts a message to all subscribers of a topic.
  """
  def broadcast(topic, message) do
    Phoenix.PubSub.broadcast(PIIGuardian.PubSub, topic, message)
  end

  @doc """
  Broadcasts a message to all subscribers of a topic except the given pid.
  """
  def broadcast_from(from_pid, topic, message) do
    Phoenix.PubSub.broadcast_from(PIIGuardian.PubSub, from_pid, topic, message)
  end

  @doc """
  Subscribes the caller to the given topic.
  """
  def subscribe(topic) do
    Phoenix.PubSub.subscribe(PIIGuardian.PubSub, topic)
  end

  @doc """
  Unsubscribes the caller from the given topic.
  """
  def unsubscribe(topic) do
    Phoenix.PubSub.unsubscribe(PIIGuardian.PubSub, topic)
  end
end
