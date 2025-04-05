defmodule PiiGuardian.NotionEventHandlerTest do
  use PiiGuardian.DataCase, async: false
  
  import Mox
  
  alias PiiGuardian.MockNotionApi
  alias PiiGuardian.MockAnthropix
  alias PiiGuardian.MockSlackbot
  alias PiiGuardian.NotionEventHandler
  alias PiiGuardian.NotionEventMocks
  
  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!
  
  # Allow mocks to be called from any process
  setup do
    Mox.set_mox_global()
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
        {:ok, [
          %{"type" => "paragraph", "paragraph" => %{"rich_text" => [%{"plain_text" => "Safe content"}]}},
          %{"type" => "heading_1", "heading_1" => %{"rich_text" => [%{"plain_text" => "Test Heading"}]}}
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
        {:ok, [
          %{"type" => "paragraph", "paragraph" => %{"rich_text" => [%{"plain_text" => "Email: test@example.com"}]}},
          %{"type" => "heading_1", "heading_1" => %{"rich_text" => [%{"plain_text" => "Contact Info"}]}}
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
        {:ok, %{
          "properties" => %{
            "title" => %{
              "title" => [%{"plain_text" => "Test Page With PII"}]
            }
          }
        }}
      end)
      
      # Mock Slackbot.dm_author_about_notion_pii
      expect(MockSlackbot, :dm_author_about_notion_pii, fn 
        "author@example.com", ^page_id, "Test Page With PII", ^explanation -> :ok
      end)
      
      assert NotionEventHandler.handle(event) == :ok
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
        {:ok, [
          %{"type" => "paragraph", "paragraph" => %{"rich_text" => [%{"plain_text" => "Some text"}]}},
          %{"type" => "file", "file" => %{"external" => %{"url" => "https://example.com/file.pdf"}}}
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
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] PDF contains SSN and credit card numbers"}]}}
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
        {:ok, %{
          "properties" => %{
            "Name" => %{
              "title" => [%{"plain_text" => "PDF With PII"}]
            }
          }
        }}
      end)
      
      # Mock Slackbot.dm_author_about_notion_pii
      expect(MockSlackbot, :dm_author_about_notion_pii, fn email, ^page_id, title, explanation ->
        assert email == "author@example.com"
        assert title == "PDF With PII"
        assert String.contains?(explanation, "PDF contains SSN")
        :ok
      end)
      
      assert NotionEventHandler.handle(event) == :ok
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
        {:ok, [
          %{"type" => "paragraph", "paragraph" => %{"rich_text" => [%{"plain_text" => "Email: test@example.com"}]}}
        ]}
      end)
      
      # Mock delete page to return error
      expect(MockNotionApi, :delete_page, fn ^page_id ->
        {:error, "Permission denied"}
      end)
      
      assert {:error, "Permission denied"} = NotionEventHandler.handle(event)
    end
  end
  
  describe "handle/1 for page.content_updated event" do
    test "handles updated page with updated blocks (no PII)" do
      event = NotionEventMocks.updated_issue_event()
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
      
      # Mock getting block
      expect(MockNotionApi, :get_block, fn ^block_id ->
        {:ok, %{
          "type" => "paragraph",
          "paragraph" => %{"rich_text" => [%{"plain_text" => "Safe content"}]}
        }}
      end)
      
      assert NotionEventHandler.handle(event) == :ok
    end
    
    test "handles updated page with unsafe block" do
      event = NotionEventMocks.updated_issue_event()
      page_id = event["entity"]["id"]
      block_id = hd(event["data"]["updated_blocks"])["id"]
      author_id = hd(event["authors"])["id"]
      
      # Mock NotionApi.get_page
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{"archived" => false}}
      end)
      
      # Mock get_block
      expect(MockNotionApi, :get_block, fn ^block_id ->
        {:ok, %{
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
        {:ok, %{
          "properties" => %{
            "title" => %{
              "title" => [%{"plain_text" => "Updated Page With PII"}]
            }
          }
        }}
      end)
      
      # Mock Slackbot.dm_author_about_notion_pii
      expect(MockSlackbot, :dm_author_about_notion_pii, fn email, ^page_id, title, explanation ->
        assert email == "author@example.com"
        assert title == "Updated Page With PII"
        assert String.contains?(explanation, "Block contains SSN")
        :ok
      end)
      
      assert NotionEventHandler.handle(event) == :ok
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
        {:ok, [
          %{"type" => "paragraph", "paragraph" => %{"rich_text" => [%{"plain_text" => "Safe content"}]}}
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
      page_id = "fake-page-id"
      author_id = "fake-author-id"
      explanation = "Found SSN in content"
      
      # Create event with authors
      event = %{
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
        {:ok, [
          %{"type" => "paragraph", "paragraph" => %{"rich_text" => [%{"plain_text" => "SSN: 123-45-6789"}]}}
        ]}
      end)
      
      # Mock delete page
      expect(MockNotionApi, :delete_page, fn ^page_id ->
        {:ok, %{"archived" => true}}
      end)
      
      # Mock get_user with no email
      expect(MockNotionApi, :get_user, fn ^author_id ->
        {:ok, %{"name" => "Author Name"}} # Missing "person" with email
      end)
      
      # Mock get_page for title
      expect(MockNotionApi, :get_page, fn ^page_id ->
        {:ok, %{
          "properties" => %{
            "title" => %{
              "title" => [%{"plain_text" => "Page With PII"}]
            }
          }
        }}
      end)
      
      # No expectation for Slackbot.dm_author_about_notion_pii since email is missing
      
      assert NotionEventHandler.handle(event) == :ok
    end
    
    test "handles non-person author" do
      page_id = "fake-page-id"
      
      # Create event with non-person author
      event = %{
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
        {:ok, [
          %{"type" => "paragraph", "paragraph" => %{"rich_text" => [%{"plain_text" => "Private data"}]}}
        ]}
      end)
      
      # Mock delete page
      expect(MockNotionApi, :delete_page, fn ^page_id ->
        {:ok, %{"archived" => true}}
      end)
      
      # No notification should happen for bot authors
      
      assert NotionEventHandler.handle(event) == :ok
    end
    
    test "handles failure to notify author via Slack" do
      page_id = "fake-page-id"
      author_id = "fake-author-id"
      explanation = "Found credit card number"
      
      # Create event with authors
      event = %{
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
        {:ok, [
          %{"type" => "paragraph", "paragraph" => %{"rich_text" => [%{"plain_text" => "Credit card: 4111-1111-1111-1111"}]}}
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
        {:ok, %{
          "properties" => %{
            "title" => %{
              "title" => [%{"plain_text" => "Page With PII"}]
            }
          }
        }}
      end)
      
      # Mock Slackbot.dm_author_about_notion_pii with error
      expect(MockSlackbot, :dm_author_about_notion_pii, fn _email, _page_id, _title, _explanation ->
        {:error, "User not found on Slack"}
      end)
      
      assert NotionEventHandler.handle(event) == :ok
    end
    
    test "extracts page title from different property formats" do
      page_id = "fake-page-id"
      author_id = "fake-author-id"
      explanation = "Found PII"
      
      # Create event with authors
      event = %{
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
        {:ok, [
          %{"type" => "paragraph", "paragraph" => %{"rich_text" => [%{"plain_text" => "Private data"}]}}
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
        {:ok, %{
          "properties" => %{
            "Custom Title" => %{"type" => "title", "title" => [%{"plain_text" => "Custom Title Page"}]}
          }
        }}
      end)
      
      # Mock Slackbot.dm_author_about_notion_pii
      expect(MockSlackbot, :dm_author_about_notion_pii, fn _email, _page_id, title, _explanation ->
        assert title == "Custom Title Page"
        :ok
      end)
      
      assert NotionEventHandler.handle(event) == :ok
    end
  end
end