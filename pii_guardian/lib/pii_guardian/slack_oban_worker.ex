defmodule PiiGuardian.SlackObanWorker do
  @moduledoc """
  Worker to process Slack events

  We save the entire "event" map in the event as the args.
  """
  use Oban.Worker, queue: :slack

  alias PiiGuardian.SlackEventHandler

  @type enqueue_result :: {:ok, Oban.Job.t()} | {:error, term()}
  @type event :: %{String.t() => term()}

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    SlackEventHandler.handle(args)
  end

  @spec enqueue_event_to_handle(event()) :: enqueue_result()
  def enqueue_event_to_handle(event) do
    event
    |> __MODULE__.new()
    |> Oban.insert()
  end
end
