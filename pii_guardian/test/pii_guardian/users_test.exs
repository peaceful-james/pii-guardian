defmodule PIIGuardian.UsersTest do
  use ExUnit.Case
  
  alias PIIGuardian.Users.Resolver
  
  setup do
    # Ensure the GenServer is started before tests
    start_supervised!(PIIGuardian.Users.Resolver)
    :ok
  end
  
  describe "Resolver" do
    test "get_slack_user_for_notion_user/1 returns slack user for known notion user" do
      assert {:ok, "U12345678"} = Resolver.get_slack_user_for_notion_user("notion_user_1")
    end
    
    test "get_slack_user_for_notion_user/1 returns slack user for known email" do
      assert {:ok, "U12345678"} = Resolver.get_slack_user_for_notion_user("test@example.com")
    end
    
    test "add_mapping/2 successfully adds a new mapping" do
      # Add a new mapping
      :ok = Resolver.add_mapping("new_notion_user", "UNEWUSER")
      
      # Verify the mapping was added
      assert {:ok, "UNEWUSER"} = Resolver.get_slack_user_for_notion_user("new_notion_user")
    end
    
    test "add_mapping/2 can update an existing mapping" do
      # Get the current mapping
      {:ok, original_slack_id} = Resolver.get_slack_user_for_notion_user("notion_user_2")
      
      # Update the mapping
      :ok = Resolver.add_mapping("notion_user_2", "UUPDATED")
      
      # Verify the mapping was updated
      assert {:ok, "UUPDATED"} = Resolver.get_slack_user_for_notion_user("notion_user_2")
      refute original_slack_id == "UUPDATED"
    end
  end
end