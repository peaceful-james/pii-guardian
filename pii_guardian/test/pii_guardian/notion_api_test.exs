defmodule PiiGuardian.NotionApiTest do
  use ExUnit.Case, async: true

  import Tesla.Mock

  alias PiiGuardian.NotionApi

  # Helper to return JSON responses with status 200
  defp build_json_env(body) do
    %Tesla.Env{
      status: 200,
      body: body,
      headers: [{"content-type", "application/json"}]
    }
  end

  # Make sure your test environment has an API token set
  setup_all do
    Application.put_env(:pii_guardian, :notion_api_token, "test_token")
    :ok
  end

  describe "get_page/1" do
    test "returns page data when request is successful" do
      page_id = "abc123"

      mock(fn
        %{method: :get, url: "https://api.notion.com/v1/pages/" <> ^page_id} ->
          build_json_env(%{
            "id" => page_id,
            "properties" => %{
              "title" => %{
                "title" => [%{"plain_text" => "Test Page"}]
              }
            }
          })
      end)

      assert {:ok, page} = NotionApi.get_page(page_id)
      assert page["id"] == page_id

      assert get_in(page, ["properties", "title", "title", Access.at(0), "plain_text"]) ==
               "Test Page"
    end

    test "returns error when API returns non-200 status code" do
      page_id = "invalid123"

      mock(fn
        %{method: :get, url: "https://api.notion.com/v1/pages/" <> ^page_id} ->
          %Tesla.Env{
            status: 404,
            body: %{"message" => "Page not found"}
          }
      end)

      assert {:error, error} = NotionApi.get_page(page_id)
      assert error =~ "HTTP error 404"
      assert error =~ "Page not found"
    end

    test "returns error when client error occurs" do
      page_id = "network_error"

      mock(fn
        %{method: :get, url: "https://api.notion.com/v1/pages/" <> ^page_id} ->
          {:error, :timeout}
      end)

      assert {:error, error} = NotionApi.get_page(page_id)
      assert error =~ "Client error"
      assert error =~ "timeout"
    end
  end

  describe "get_page_content/3" do
    test "returns page content with default parameters" do
      page_id = "content123"

      mock(fn
        %{
          method: :get,
          url: "https://api.notion.com/v1/blocks/" <> ^page_id <> "/children",
          query: [page_size: 100]
        } ->
          build_json_env(%{
            "results" => [
              %{"type" => "paragraph", "paragraph" => %{"text" => "Hello world"}}
            ],
            "has_more" => false
          })
      end)

      assert {:ok, response} = NotionApi.get_page_content(page_id)
      assert length(response["results"]) == 1
      assert hd(response["results"])["type"] == "paragraph"
      assert response["has_more"] == false
    end

    test "passes start_cursor and page_size when provided" do
      page_id = "content123"
      cursor = "cursor123"

      mock(fn
        %{
          method: :get,
          url: "https://api.notion.com/v1/blocks/" <> ^page_id <> "/children",
          query: [start_cursor: ^cursor, page_size: 50]
        } ->
          build_json_env(%{
            "results" => [
              %{"type" => "paragraph", "paragraph" => %{"text" => "More content"}}
            ],
            "has_more" => false
          })
      end)

      assert {:ok, response} = NotionApi.get_page_content(page_id, cursor, 50)
      assert length(response["results"]) == 1
      assert hd(response["results"])["type"] == "paragraph"
    end
  end

  describe "delete_page/1" do
    test "archives a page successfully" do
      page_id = "delete123"
      expected_body = JSON.encode!(%{"archived" => true})

      mock(fn
        %{
          method: :patch,
          url: "https://api.notion.com/v1/pages/" <> ^page_id,
          body: ^expected_body
        } ->
          build_json_env(%{
            "id" => page_id,
            "archived" => true
          })
      end)

      assert {:ok, response} = NotionApi.delete_page(page_id)
      assert response["id"] == page_id
      assert response["archived"] == true
    end

    test "returns error when delete fails" do
      page_id = "nodelete123"

      mock(fn
        %{method: :patch, url: "https://api.notion.com/v1/pages/" <> ^page_id} ->
          %Tesla.Env{
            status: 403,
            body: %{"message" => "Permission denied"}
          }
      end)

      assert {:error, error} = NotionApi.delete_page(page_id)
      assert error =~ "Permission denied"
    end
  end

  describe "get_block/1" do
    test "retrieves a block by id" do
      block_id = "block123"

      mock(fn
        %{method: :get, url: "https://api.notion.com/v1/blocks/" <> ^block_id} ->
          build_json_env(%{
            "id" => block_id,
            "type" => "heading_1",
            "heading_1" => %{
              "rich_text" => [%{"plain_text" => "Heading"}]
            }
          })
      end)

      assert {:ok, block} = NotionApi.get_block(block_id)
      assert block["id"] == block_id
      assert block["type"] == "heading_1"
    end

    test "returns error when block not found" do
      block_id = "nonexistent"

      mock(fn
        %{method: :get, url: "https://api.notion.com/v1/blocks/" <> ^block_id} ->
          %Tesla.Env{
            status: 404,
            body: %{"message" => "Block not found"}
          }
      end)

      assert {:error, error} = NotionApi.get_block(block_id)
      assert error =~ "Block not found"
    end
  end

  describe "delete_block/1" do
    test "archives a block successfully" do
      block_id = "deleteme"
      expected_body = JSON.encode!(%{"archived" => true})

      mock(fn
        %{
          method: :patch,
          url: "https://api.notion.com/v1/blocks/" <> ^block_id,
          body: ^expected_body
        } ->
          build_json_env(%{
            "id" => block_id,
            "archived" => true
          })
      end)

      assert {:ok, response} = NotionApi.delete_block(block_id)
      assert response["id"] == block_id
      assert response["archived"] == true
    end
  end

  describe "get_user/1" do
    test "retrieves a user by id" do
      user_id = "user123"

      mock(fn
        %{method: :get, url: "https://api.notion.com/v1/users/" <> ^user_id} ->
          build_json_env(%{
            "id" => user_id,
            "name" => "Test User",
            "type" => "person",
            "person" => %{
              "email" => "user@example.com"
            }
          })
      end)

      assert {:ok, user} = NotionApi.get_user(user_id)
      assert user["id"] == user_id
      assert user["name"] == "Test User"
      assert user["person"]["email"] == "user@example.com"
    end
  end

  describe "get_all_page_content/1" do
    test "aggregates all content when there are multiple pages" do
      page_id = "paginated"

      # First request returns first page with next_cursor
      mock(fn
        %{
          method: :get,
          url: "https://api.notion.com/v1/blocks/" <> ^page_id <> "/children",
          query: [page_size: 100]
        } ->
          build_json_env(%{
            "results" => [
              %{"id" => "block1", "type" => "paragraph"}
            ],
            "has_more" => true,
            "next_cursor" => "cursor123"
          })

        %{
          method: :get,
          url: "https://api.notion.com/v1/blocks/" <> ^page_id <> "/children",
          query: [start_cursor: "cursor123", page_size: 100]
        } ->
          build_json_env(%{
            "results" => [
              %{"id" => "block2", "type" => "heading_1"}
            ],
            "has_more" => false
          })
      end)

      assert {:ok, results} = NotionApi.get_all_page_content(page_id)
      assert length(results) == 2
      assert Enum.at(results, 0)["id"] == "block1"
      assert Enum.at(results, 1)["id"] == "block2"
    end

    test "returns error when API call fails" do
      page_id = "error_page"

      mock(fn
        %{method: :get, url: "https://api.notion.com/v1/blocks/" <> ^page_id <> "/children"} ->
          %Tesla.Env{
            status: 500,
            body: %{"message" => "Server error"}
          }
      end)

      assert {:error, error} = NotionApi.get_all_page_content(page_id)
      assert error =~ "Server error"
    end
  end

  describe "download_file/1" do
    test "downloads file content with mimetype" do
      url = "https://example.com/file.pdf"

      mock(fn
        %{method: :get, url: ^url} ->
          %Tesla.Env{
            status: 200,
            body: "PDF content",
            headers: [{"content-type", "application/pdf"}]
          }
      end)

      assert {:ok, %{body: body, mimetype: mimetype}} = NotionApi.download_file(url)
      assert body == "PDF content"
      assert mimetype == "application/pdf"
    end

    test "returns error when download fails" do
      url = "https://example.com/not-found.pdf"

      mock(fn
        %{method: :get, url: ^url} ->
          %Tesla.Env{
            status: 404,
            body: "Not Found"
          }
      end)

      assert {:error, error} = NotionApi.download_file(url)
      assert error =~ "HTTP error 404"
    end

    test "handles network errors" do
      url = "https://example.com/network-error.pdf"

      mock(fn
        %{method: :get, url: ^url} ->
          {:error, :timeout}
      end)

      assert {:error, error} = NotionApi.download_file(url)
      assert error =~ "Download error"
      assert error =~ "timeout"
    end
  end
end
