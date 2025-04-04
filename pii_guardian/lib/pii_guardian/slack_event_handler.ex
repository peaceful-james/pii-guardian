defmodule PiiGuardian.SlackEventHandler do
  @moduledoc """
    Handles Slack events.
  """

  def handle(event) do
    IO.inspect(event, label: "Received Slack event")
    :ok
  end
end
