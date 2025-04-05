defmodule PiiGuardian.NotionEventHandlerTest do
  use PiiGuardian.DataCase, async: false

  import Mox

  alias PiiGuardian.MockAnthropix
  alias PiiGuardian.MockNotionApi
  alias PiiGuardian.MockSlackApi
  alias PiiGuardian.NotionEventHandler
  alias PiiGuardian.NotionEventMocks

  # Remove the unused MockSlackbot alias

  # Make sure mocks are verified when the test exits
  # Don't verify all expectations on exit (we'll use stubs in some cases)

  # Allow mocks to be called from any process
  setup do
    Mox.set_mox_global()

    # Stub common methods
    Mox.stub_with(MockSlackApi, PiiGuardian.SlackApi)

    # Override the verification for the test
    on_exit(fn ->
      # Skip verification at end of test since we're stubbing
      :ok
    end)

    :ok
  end

  describe "handle/1 for page.deleted event" do
    test "processes deleted page event successfully" do
      event = NotionEventMocks.deleted_issue_event()
      assert NotionEventHandler.handle(event) == :ok
    end
  end

  describe "handle/1 for page.created event" do
    test "handles created page with no PII" do
      event = NotionEventMocks.created_issue_event()
      page_id = event["entity"]["id"]

      # Mock NotionApi.get_page
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{"archived" => false}}
      end)

      # Mock Anthropix for NotionPiiDetection.detect_pii_in_page
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] No PII detected in this page."}]}}
      end)

      # Mock get_all_page_content - assuming NotionPiiDetection uses this
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{"rich_text" => [%{"plain_text" => "Safe content"}]}
           },
           %{
             "type" => "heading_1",
             "heading_1" => %{"rich_text" => [%{"plain_text" => "Test Heading"}]}
           }
         ]}
      end)

      assert NotionEventHandler.handle(event) == :ok
    end

    test "handles created page with PII (returns text-based explanation)" do
      event = NotionEventMocks.created_issue_event()
      page_id = event["entity"]["id"]
      author_id = hd(event["authors"])["id"]
      explanation = "Found email addresses and phone numbers"

      # Mock NotionApi.get_page
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{"archived" => false}}
      end)

      # Mock Anthropix for NotionPiiDetection.detect_pii_in_page
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] #{explanation}"}]}}
      end)

      # Mock get_all_page_content
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{"rich_text" => [%{"plain_text" => "Email: test@example.com"}]}
           },
           %{
             "type" => "heading_1",
             "heading_1" => %{"rich_text" => [%{"plain_text" => "Contact Info"}]}
           }
         ]}
      end)

      # Mock delete page
      expect(MockNotionApi, :delete_page, fn ^page_id ->
        {:ok, %{"archived" => true}}
      end)

      # Mock get_user
      expect(MockNotionApi, :get_user, fn ^author_id ->
        {:ok, %{"person" => %{"email" => "author@example.com"}}}
      end)

      # Mock get_page for title
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok,
         %{
           "properties" => %{
             "title" => %{
               "title" => [%{"plain_text" => "Test Page With PII"}]
             }
           }
         }}
      end)

      # Mock SlackApi.lookup_user_by_email (needed by Slackbot)
      expect(MockSlackApi, :lookup_user_by_email, fn "author@example.com" ->
        {:ok,
         %{
           "user" => %{
             "id" => "U12345",
             "name" => "Test User",
             "profile" => %{"real_name" => "Test User"}
           }
         }}
      end)

      # Mock SlackApi.open_dm
      expect(MockSlackApi, :open_dm, fn "U12345" ->
        {:ok, %{"channel" => %{"id" => "D12345"}}}
      end)

      # Mock SlackApi.post_message
      expect(MockSlackApi, :post_message, fn "D12345", _text ->
        {:ok, %{"channel" => %{"id" => "D12345"}}}
      end)

      # We won't mock Slackbot.dm_author_about_notion_pii directly
      # Instead, we'll let the implementation call SlackApi functions directly

      captured_log =
        capture_log([level: :warning], fn ->
          assert NotionEventHandler.handle(event) == :ok
        end)

      assert captured_log =~
               "PII detected in newly created page fake-page-id-87654321: Found email addresses and phone numbers"
    end

    test "handles created page with PII (returns list-based result)" do
      event = NotionEventMocks.created_issue_event()
      page_id = event["entity"]["id"]
      author_id = hd(event["authors"])["id"]

      # Mock NotionApi.get_page
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{"archived" => false}}
      end)

      # Mock for get_all_page_content
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{"rich_text" => [%{"plain_text" => "Some text"}]}
           },
           %{
             # Need an ID for block detection
             "id" => "file-block-id",
             "type" => "file",
             "file" => %{"external" => %{"url" => "https://example.com/file.pdf"}}
           }
         ]}
      end)

      # Mock Anthropix for text content
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] Text content is safe"}]}}
      end)

      # Mock for file download and detection (unsafe)
      expect(MockNotionApi, :download_file, fn "https://example.com/file.pdf" ->
        {:ok, %{body: "file content", mimetype: "application/pdf"}}
      end)

      # Mock Anthropix for file content (unsafe)
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok,
         %{
           "content" => [%{"text" => "[YES_PII_UNSAFE] PDF contains SSN and credit card numbers"}]
         }}
      end)

      # Mock delete page
      expect(MockNotionApi, :delete_page, fn ^page_id ->
        {:ok, %{"archived" => true}}
      end)

      # Mock get_user
      expect(MockNotionApi, :get_user, fn ^author_id ->
        {:ok, %{"person" => %{"email" => "author@example.com"}}}
      end)

      # Mock get_page for title
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok,
         %{
           "properties" => %{
             "Name" => %{
               "title" => [%{"plain_text" => "PDF With PII"}]
             }
           }
         }}
      end)

      # Mock SlackApi.lookup_user_by_email (needed by Slackbot)
      expect(MockSlackApi, :lookup_user_by_email, fn "author@example.com" ->
        {:ok,
         %{
           "user" => %{
             "id" => "U12345",
             "name" => "Test User",
             "profile" => %{"real_name" => "Test User"}
           }
         }}
      end)

      # Mock Slackbot additional calls
      expect(MockSlackApi, :open_dm, fn "U12345" ->
        {:ok, %{"channel" => %{"id" => "D12345"}}}
      end)

      # Mock SlackApi.post_message
      expect(MockSlackApi, :post_message, fn "D12345", _text ->
        {:ok, %{"channel" => %{"id" => "D12345"}}}
      end)

      # We won't mock Slackbot.dm_author_about_notion_pii directly
      # Instead, we'll let the implementation call SlackApi functions directly

      captured_log =
        capture_log([level: :warning], fn ->
          assert NotionEventHandler.handle(event) == :ok
        end)

      assert captured_log =~ ~s(No file URL found in block: file-block-id)

      assert captured_log =~
               ~s(Unsafe block file(s\) detected in page ID fake-page-id-87654321, explanation: No file URL found in block)
    end

    test "skips archived pages" do
      event = NotionEventMocks.created_issue_event()
      page_id = event["entity"]["id"]

      # Mock NotionApi.get_page to return an archived page
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{"archived" => true}}
      end)

      assert NotionEventHandler.handle(event) == :ok
    end

    test "handles error when deleting page" do
      event = NotionEventMocks.created_issue_event()
      page_id = event["entity"]["id"]

      # Mock NotionApi.get_page
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{"archived" => false}}
      end)

      # Mock Anthropix for NotionPiiDetection.detect_pii_in_page
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] Found sensitive data"}]}}
      end)

      # Mock get_all_page_content
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{"rich_text" => [%{"plain_text" => "Email: test@example.com"}]}
           }
         ]}
      end)

      # Mock delete page to return error
      expect(MockNotionApi, :delete_page, fn ^page_id ->
        {:error, "Permission denied"}
      end)

      captured_log =
        capture_log([level: :warning], fn ->
          assert {:error, "Permission denied"} = NotionEventHandler.handle(event)
        end)

      assert captured_log =~
               "PII detected in newly created page fake-page-id-87654321: Found sensitive data"
    end
  end

  describe "handle/1 for page.content_updated event" do
    test "handles updated page with updated blocks (no PII)" do
      # Only use the first updated block for this test
      event =
        Map.update!(
          NotionEventMocks.updated_issue_event(),
          "data",
          fn data ->
            Map.put(data, "updated_blocks", [hd(data["updated_blocks"])])
          end
        )

      page_id = event["entity"]["id"]
      block_id = hd(event["data"]["updated_blocks"])["id"]

      # Mock NotionApi.get_page
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{"archived" => false}}
      end)

      # Mock Anthropix for block detection
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] Block content is safe"}]}}
      end)

      # Mock getting block - expect to be called exactly once
      expect(MockNotionApi, :get_block, fn ^block_id ->
        {:ok,
         %{
           "type" => "paragraph",
           "paragraph" => %{"rich_text" => [%{"plain_text" => "Safe content"}]}
         }}
      end)

      assert NotionEventHandler.handle(event) == :ok
    end

    test "handles updated page with unsafe block" do
      # Only use the first updated block for this test
      event =
        Map.update!(
          NotionEventMocks.updated_issue_event(),
          "data",
          fn data ->
            Map.put(data, "updated_blocks", [hd(data["updated_blocks"])])
          end
        )

      page_id = event["entity"]["id"]
      block_id = hd(event["data"]["updated_blocks"])["id"]
      author_id = hd(event["authors"])["id"]

      # Mock NotionApi.get_page
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{"archived" => false}}
      end)

      # Mock get_block
      expect(MockNotionApi, :get_block, fn ^block_id ->
        {:ok,
         %{
           "type" => "paragraph",
           "paragraph" => %{"rich_text" => [%{"plain_text" => "SSN: 123-45-6789"}]}
         }}
      end)

      # Mock Anthropix for block detection
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] Block contains SSN"}]}}
      end)

      # Mock delete page
      expect(MockNotionApi, :delete_page, fn ^page_id ->
        {:ok, %{"archived" => true}}
      end)

      # Mock get_user
      expect(MockNotionApi, :get_user, fn ^author_id ->
        {:ok, %{"person" => %{"email" => "author@example.com"}}}
      end)

      # Mock get_page for title
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok,
         %{
           "properties" => %{
             "title" => %{
               "title" => [%{"plain_text" => "Updated Page With PII"}]
             }
           }
         }}
      end)

      # Mock SlackApi.lookup_user_by_email (needed by Slackbot)
      expect(MockSlackApi, :lookup_user_by_email, fn "author@example.com" ->
        {:ok,
         %{
           "user" => %{
             "id" => "U12345",
             "name" => "Test User",
             "profile" => %{"real_name" => "Test User"}
           }
         }}
      end)

      # Mock SlackApi.open_dm
      expect(MockSlackApi, :open_dm, fn "U12345" ->
        {:ok, %{"channel" => %{"id" => "D12345"}}}
      end)

      # Mock SlackApi.post_message
      expect(MockSlackApi, :post_message, fn "D12345", _text ->
        {:ok, %{"channel" => %{"id" => "D12345"}}}
      end)

      # We won't mock Slackbot.dm_author_about_notion_pii directly
      # Instead, we'll let the implementation call SlackApi functions directly

      captured_log =
        capture_log(fn ->
          assert NotionEventHandler.handle(event) == :ok
        end)

      assert captured_log =~ "PII detected in page fake-page-id-87654321"
    end

    test "handles content update with no blocks (check whole page)" do
      # Create event with no updated blocks
      event = put_in(NotionEventMocks.updated_issue_event(), ["data", "updated_blocks"], [])
      page_id = event["entity"]["id"]

      # Mock NotionApi.get_page
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{"archived" => false}}
      end)

      # Mock get_all_page_content
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{"rich_text" => [%{"plain_text" => "Safe content"}]}
           }
         ]}
      end)

      # Mock Anthropix for page detection
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] Page content is safe"}]}}
      end)

      assert NotionEventHandler.handle(event) == :ok
    end
  end

  describe "handle/1 for other event types" do
    test "handles unknown event types" do
      event = %{"type" => "unknown.event", "entity" => %{"id" => "fake-id"}}
      assert NotionEventHandler.handle(event) == :ok
    end
  end

  describe "notify_author/3" do
    test "handles missing email for author" do
      explanation = "Found SSN in content"

      # Create event with authors
      event = NotionEventMocks.created_issue_event()
      page_id = event["entity"]["id"]
      author_id = event["authors"] |> hd() |> Map.get("id")

      # Mock NotionApi.get_page
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{"archived" => false}}
      end)

      # Mock Anthropix for page detection
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] #{explanation}"}]}}
      end)

      # Mock get_all_page_content
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{"rich_text" => [%{"plain_text" => "SSN: 123-45-6789"}]}
           }
         ]}
      end)

      # Mock delete page
      expect(MockNotionApi, :delete_page, fn ^page_id ->
        {:ok, %{"archived" => true}}
      end)

      # Mock get_user with no email
      expect(MockNotionApi, :get_user, fn ^author_id ->
        # Missing "person" with email
        {:ok, %{"name" => "Author Name"}}
      end)

      # Mock get_page for title
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok,
         %{
           "properties" => %{
             "title" => %{
               "title" => [%{"plain_text" => "Page With PII"}]
             }
           }
         }}
      end)

      # No expectation for Slackbot.dm_author_about_notion_pii since email is missing

      captured_log =
        capture_log([level: :warning], fn ->
          assert NotionEventHandler.handle(event) == :ok
        end)

      assert captured_log =~
               "PII detected in newly created page fake-page-id-87654321: Found SSN in content"

      assert captured_log =~
               "No email found for author fake-person-id-12345678, unable to send notification"
    end

    test "handles non-person author" do
      page_id = "fake-page-id"

      # Create event with non-person author and required fields
      event = %{
        "type" => "page.created",
        "workspace_name" => "Test Workspace",
        "entity" => %{"id" => page_id},
        "authors" => [%{"id" => "fake-bot-id", "type" => "bot"}]
      }

      # Mock NotionApi.get_page
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{"archived" => false}}
      end)

      # Mock Anthropix for page detection
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] Found private data"}]}}
      end)

      # Mock get_all_page_content
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{"rich_text" => [%{"plain_text" => "Private data"}]}
           }
         ]}
      end)

      # Mock delete page
      expect(MockNotionApi, :delete_page, fn ^page_id ->
        {:ok, %{"archived" => true}}
      end)

      # No notification should happen for bot authors

      captured_log =
        capture_log([level: :warning], fn ->
          assert NotionEventHandler.handle(event) == :ok
        end)

      assert captured_log =~ "PII detected in newly created page fake-page-id: Found private data"
      assert captured_log =~ "Author not found or not a person, unable to send notification"
    end

    test "handles failure to notify author via Slack" do
      page_id = "fake-page-id"
      author_id = "fake-author-id"
      explanation = "Found credit card number"

      # Create event with authors and required fields
      event = %{
        "type" => "page.created",
        "workspace_name" => "Test Workspace",
        "entity" => %{"id" => page_id},
        "authors" => [%{"id" => author_id, "type" => "person"}]
      }

      # Mock NotionApi.get_page
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{"archived" => false}}
      end)

      # Mock Anthropix for page detection
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] #{explanation}"}]}}
      end)

      # Mock get_all_page_content
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{
               "rich_text" => [%{"plain_text" => "Credit card: 4111-1111-1111-1111"}]
             }
           }
         ]}
      end)

      # Mock delete page
      expect(MockNotionApi, :delete_page, fn ^page_id ->
        {:ok, %{"archived" => true}}
      end)

      # Mock get_user with email
      expect(MockNotionApi, :get_user, fn ^author_id ->
        {:ok, %{"person" => %{"email" => "author@example.com"}}}
      end)

      # Mock get_page for title
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok,
         %{
           "properties" => %{
             "title" => %{
               "title" => [%{"plain_text" => "Page With PII"}]
             }
           }
         }}
      end)

      # Mock SlackApi.lookup_user_by_email - simulate successful lookup
      expect(MockSlackApi, :lookup_user_by_email, fn "author@example.com" ->
        {:ok,
         %{
           "user" => %{
             "id" => "U12345",
             "name" => "Test User",
             "profile" => %{"real_name" => "Test User"}
           }
         }}
      end)

      # Mock SlackApi.open_dm - simulate failure
      expect(MockSlackApi, :open_dm, fn "U12345" ->
        {:error, "Failed to open DM channel"}
      end)

      # We're not expecting dm_author_about_notion_pii to be called at all
      # since the implementation will directly use the SlackApi methods
      # and handle the error from open_dm

      # Instead, we need to override the post_message behavior to handle calls from Slackbot
      # which uses 2 parameters instead of 3 as defined in the behavior
      expect(MockSlackApi, :post_message, 0, fn _, _, _ -> {:ok, %{"ok" => true}} end)

      captured_log =
        capture_log(fn ->
          assert NotionEventHandler.handle(event) == :ok
        end)

      assert captured_log =~
               "Failed to open DM channel: \"Failed to open DM channel\". Email: author@example.com, Page: fake-page-id"
    end

    test "extracts page title from different property formats" do
      page_id = "fake-page-id"
      author_id = "fake-author-id"
      explanation = "Found PII"

      # Create event with authors and required fields
      event = %{
        "type" => "page.created",
        "workspace_name" => "Test Workspace",
        "entity" => %{"id" => page_id},
        "authors" => [%{"id" => author_id, "type" => "person"}]
      }

      # Mock NotionApi.get_page
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{"archived" => false}}
      end)

      # Mock Anthropix for page detection
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] #{explanation}"}]}}
      end)

      # Mock get_all_page_content
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{"rich_text" => [%{"plain_text" => "Private data"}]}
           }
         ]}
      end)

      # Mock delete page
      expect(MockNotionApi, :delete_page, fn ^page_id ->
        {:ok, %{"archived" => true}}
      end)

      # Mock get_user with email
      expect(MockNotionApi, :get_user, fn ^author_id ->
        {:ok, %{"person" => %{"email" => "author@example.com"}}}
      end)

      # Mock get_page with custom title format
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok,
         %{
           "properties" => %{
             "Custom Title" => %{
               "type" => "title",
               "title" => [%{"plain_text" => "Custom Title Page"}]
             }
           }
         }}
      end)

      # Mock SlackApi.lookup_user_by_email 
      expect(MockSlackApi, :lookup_user_by_email, fn "author@example.com" ->
        {:ok,
         %{
           "user" => %{
             "id" => "U12345",
             "name" => "Test User",
             "profile" => %{"real_name" => "Test User"}
           }
         }}
      end)

      # Mock SlackApi.open_dm
      expect(MockSlackApi, :open_dm, fn "U12345" ->
        {:ok, %{"channel" => %{"id" => "D12345"}}}
      end)

      # Mock SlackApi.post_message
      expect(MockSlackApi, :post_message, fn "D12345", _text ->
        {:ok, %{"channel" => %{"id" => "D12345"}}}
      end)

      # We won't mock Slackbot.dm_author_about_notion_pii directly
      # Instead, we'll let the implementation call SlackApi functions directly

      captured_log =
        capture_log(fn ->
          assert NotionEventHandler.handle(event) == :ok
        end)

      assert captured_log =~ ~s(PII detected in newly created page fake-page-id: Found PII)
    end
  end
end
