defmodule PIIGuardian.NotionTest do
  use ExUnit.Case
  import Mock
  
  alias PIIGuardian.Notion.PageProcessor
  alias PIIGuardian.Notion.Actions
  alias PIIGuardian.PII.Analyzer
  alias PIIGuardian.Users.Resolver
  
  describe "PageProcessor" do
    test "process_page/2 deletes and notifies when PII is found" do
      # Mock page
      page = %{
        "id" => "page_id_123",
        "created_by" => %{"id" => "notion_user_1"},
        "properties" => %{
          "Title" => %{
            "type" => "title",
            "title" => [%{"plain_text" => "Test Page"}]
          },
          "Email" => %{
            "type" => "email",
            "email" => "test@example.com"
          }
        }
      }
      
      database_id = "db_123"
      
      # Set up mocks
      with_mocks([
        {Analyzer, [], [
          analyze_content: fn _content -> 
            {:pii_found, %{types: ["Email"]}} 
          end
        ]},
        {Actions, [], [
          delete_page: fn _page_id -> :ok end,
          notify_author: fn _author, _title, _content, _details -> :ok end
        ]}
      ]) do
        # Execute the function being tested
        PageProcessor.process_page(page, database_id)
        
        # Verify mocks were called with expected arguments
        assert called(Analyzer.analyze_content(:_))
        assert called(Actions.delete_page("page_id_123"))
        assert called(Actions.notify_author("notion_user_1", "Test Page", :_, :_))
      end
    end
    
    test "process_page/2 does nothing when no PII is found" do
      # Mock page
      page = %{
        "id" => "page_id_123",
        "created_by" => %{"id" => "notion_user_1"},
        "properties" => %{
          "Title" => %{
            "type" => "title",
            "title" => [%{"plain_text" => "Test Page"}]
          },
          "Description" => %{
            "type" => "rich_text",
            "rich_text" => [%{"plain_text" => "This is a safe description"}]
          }
        }
      }
      
      database_id = "db_123"
      
      # Set up mocks
      with_mocks([
        {Analyzer, [], [
          analyze_content: fn _content -> 
            {:no_pii} 
          end
        ]},
        {Actions, [], [
          delete_page: fn _page_id -> :ok end,
          notify_author: fn _author, _title, _content, _details -> :ok end
        ]}
      ]) do
        # Execute the function being tested
        PageProcessor.process_page(page, database_id)
        
        # Verify delete_page and notify_author were NOT called
        refute called(Actions.delete_page(:_))
        refute called(Actions.notify_author(:_, :_, :_, :_))
      end
    end
  end
  
  describe "Actions" do
    test "notify_author/4 sends notification via Slack" do
      with_mock Resolver, [
        get_slack_user_for_notion_user: fn _notion_user -> 
          {:ok, "U12345"} 
        end
      ] do
        with_mock PIIGuardian.Slack.Actions, [
          notify_user: fn _user, _message, _details -> :ok end
        ] do
          page_title = "Test Page"
          content = %{title: "Test Page", properties: [{"Email", "test@example.com"}]}
          pii_details = %{types: ["Email"]}
          
          assert :ok = Actions.notify_author("notion_user_1", page_title, content, pii_details)
          assert called(Resolver.get_slack_user_for_notion_user("notion_user_1"))
          assert called(PIIGuardian.Slack.Actions.notify_user("U12345", :_, pii_details))
        end
      end
    end
    
    test "notify_author/4 handles user resolution failure" do
      with_mock Resolver, [
        get_slack_user_for_notion_user: fn _notion_user -> 
          {:error, :not_found} 
        end
      ] do
        with_mock PIIGuardian.Slack.Actions, [
          notify_user: fn _user, _message, _details -> :ok end
        ] do
          page_title = "Test Page"
          content = %{title: "Test Page", properties: [{"Email", "test@example.com"}]}
          pii_details = %{types: ["Email"]}
          
          assert {:error, :user_not_found} = Actions.notify_author("unknown_user", page_title, content, pii_details)
          refute called(PIIGuardian.Slack.Actions.notify_user(:_, :_, :_))
        end
      end
    end
  end
end