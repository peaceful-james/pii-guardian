defmodule PiiGuardian.NotionObanWorker do
  @moduledoc """
  Worker to process Notion events

  We save the entire event map as the args.
  """
  use Oban.Worker, queue: :notion

  alias PiiGuardian.NotionEventHandler

  @type enqueue_result :: {:ok, Oban.Job.t()} | {:error, term()}
  @type event :: %{String.t() => term()}

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    NotionEventHandler.handle(args)
  end

  @spec enqueue_event_to_handle(event()) :: enqueue_result()
  def enqueue_event_to_handle(event) do
    event
    |> __MODULE__.new()
    |> Oban.insert()
  end
end
