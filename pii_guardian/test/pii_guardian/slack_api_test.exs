defmodule PiiGuardian.SlackApiTest do
  use PiiGuardian.DataCase, async: true

  alias PiiGuardian.SlackApi

  describe "get_file_info/1" do
    test "returns file info for a valid file ID" do
      file_id = "F08LV7DSJQM"
      result = SlackApi.get_file_info(file_id)
      assert {:ok, %{status: 200, body: %{"ok" => true, "file" => file_info}}} = result
      assert file_info["id"] == file_id
    end

    test "returns error for an invalid file ID" do
      invalid_file_id = "INVALID_FILE_ID"

      # Mock the Slack API response
      # Tesla.Mock.mock(fn
      # %{method: :get, url: "/api/files.info", query: [file: ^invalid_file_id]} ->
      # {:error, %{status: 404, body: %{"ok" => false, "error" => "file_not_found"}}}
      # end)

      assert {:error, %{status: 404, body: %{"ok" => false, "error" => "file_not_found"}}} =
               SlackApi.get_file_info(invalid_file_id)
    end
  end
end
