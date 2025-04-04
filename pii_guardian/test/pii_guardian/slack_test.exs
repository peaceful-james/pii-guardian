defmodule PIIGuardian.SlackTest do
  use ExUnit.Case
  import Mock
  
  alias PIIGuardian.Slack.MessageProcessor
  alias PIIGuardian.Slack.Actions
  alias PIIGuardian.PII.Analyzer
  
  describe "MessageProcessor" do
    test "process_message/2 deletes and notifies when PII is found" do
      # Mock message
      message = %{
        type: "message",
        user: "U12345",
        channel: "C12345",
        ts: "1234567890.123456",
        text: "My SSN is 123-45-6789"
      }
      
      # Mock Slack state
      slack = %{}
      
      # Set up mocks
      with_mocks([
        {Analyzer, [], [
          analyze_content: fn _content -> 
            {:pii_found, %{types: ["SSN"]}} 
          end
        ]},
        {Actions, [], [
          delete_message: fn _channel, _ts -> :ok end,
          notify_user: fn _user, _text, _details -> :ok end
        ]}
      ]) do
        # Execute the function being tested
        MessageProcessor.process_message(message, slack)
        
        # Verify mocks were called with expected arguments
        assert called(Analyzer.analyze_content(:_))
        assert called(Actions.delete_message("C12345", "1234567890.123456"))
        assert called(Actions.notify_user("U12345", :_, :_))
      end
    end
    
    test "process_message/2 does nothing when no PII is found" do
      # Mock message
      message = %{
        type: "message",
        user: "U12345",
        channel: "C12345",
        ts: "1234567890.123456",
        text: "This is a safe message"
      }
      
      # Mock Slack state
      slack = %{}
      
      # Set up mocks
      with_mocks([
        {Analyzer, [], [
          analyze_content: fn _content -> 
            {:no_pii} 
          end
        ]},
        {Actions, [], [
          delete_message: fn _channel, _ts -> :ok end,
          notify_user: fn _user, _text, _details -> :ok end
        ]}
      ]) do
        # Execute the function being tested
        MessageProcessor.process_message(message, slack)
        
        # Verify delete_message and notify_user were NOT called
        refute called(Actions.delete_message(:_, :_))
        refute called(Actions.notify_user(:_, :_, :_))
      end
    end
  end
  
  describe "Actions" do
    test "delete_message/2 handles successful deletion" do
      with_mock PIIGuardian.Slack.Connector, [
        get_client: fn -> :slack_client end
      ] do
        with_mock Slack.Web.Chat, [
          delete: fn _channel, _ts, _opts, _client -> 
            %{"ok" => true} 
          end
        ] do
          assert :ok = Actions.delete_message("C12345", "1234567890.123456")
        end
      end
    end
    
    test "delete_message/2 handles failed deletion" do
      with_mock PIIGuardian.Slack.Connector, [
        get_client: fn -> :slack_client end
      ] do
        with_mock Slack.Web.Chat, [
          delete: fn _channel, _ts, _opts, _client -> 
            %{"ok" => false, "error" => "message_not_found"} 
          end
        ] do
          assert {:error, _} = Actions.delete_message("C12345", "1234567890.123456")
        end
      end
    end
  end
end