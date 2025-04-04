defmodule PiiGuardian.NotionEventMocks do
  @moduledoc """
   Mocks for Notion events. These are used in tests to simulate Notion events.
  """

  def deleted_issue_event do
    %{
      "attempt_number" => 4,
      "authors" => [%{"id" => "fake-person-id-12345678", "type" => "person"}],
      "data" => %{
        "parent" => %{"id" => "fake-database-id-12345678", "type" => "database"}
      },
      "entity" => %{"id" => "fake-page-id-12345678", "type" => "page"},
      "id" => "fake-event-id-12345678",
      "integration_id" => "fake-integration-id-12345678",
      "subscription_id" => "fake-subscription-id-12345678",
      "timestamp" => "2025-04-04T21:32:52.904Z",
      "type" => "page.deleted",
      "workspace_id" => "fake-workspace-id-12345678",
      "workspace_name" => "Example Workspace"
    }
  end

  def created_issue_event do
    %{
      "attempt_number" => 1,
      "authors" => [%{"id" => "fake-person-id-12345678", "type" => "person"}],
      "data" => %{
        "parent" => %{"id" => "fake-database-id-12345678", "type" => "database"}
      },
      "entity" => %{"id" => "fake-page-id-87654321", "type" => "page"},
      "id" => "fake-event-id-87654321",
      "integration_id" => "fake-integration-id-12345678",
      "subscription_id" => "fake-subscription-id-12345678",
      "timestamp" => "2025-04-04T21:44:38.363Z",
      "type" => "page.created",
      "workspace_id" => "fake-workspace-id-12345678",
      "workspace_name" => "Example Workspace"
    }
  end

  def updated_issue_event do
    %{
      "attempt_number" => 1,
      "authors" => [%{"id" => "fake-person-id-12345678", "type" => "person"}],
      "data" => %{
        "parent" => %{"id" => "fake-database-id-12345678", "type" => "database"},
        "updated_blocks" => [
          %{"id" => "fake-block-id-00000001", "type" => "block"},
          %{"id" => "fake-block-id-00000002", "type" => "block"},
          %{"id" => "fake-block-id-00000003", "type" => "block"},
          %{"id" => "fake-block-id-00000004", "type" => "block"},
          %{"id" => "fake-block-id-00000005", "type" => "block"},
          %{"id" => "fake-block-id-00000006", "type" => "block"},
          %{"id" => "fake-block-id-00000007", "type" => "block"},
          %{"id" => "fake-block-id-00000008", "type" => "block"},
          %{"id" => "fake-block-id-00000009", "type" => "block"},
          %{"id" => "fake-block-id-00000010", "type" => "block"},
          %{"id" => "fake-block-id-00000011", "type" => "block"},
          %{"id" => "fake-block-id-00000012", "type" => "block"}
        ]
      },
      "entity" => %{"id" => "fake-page-id-87654321", "type" => "page"},
      "id" => "fake-event-id-abcdef123",
      "integration_id" => "fake-integration-id-12345678",
      "subscription_id" => "fake-subscription-id-12345678",
      "timestamp" => "2025-04-04T21:44:39.305Z",
      "type" => "page.content_updated",
      "workspace_id" => "fake-workspace-id-12345678",
      "workspace_name" => "Example Workspace"
    }
  end
end
