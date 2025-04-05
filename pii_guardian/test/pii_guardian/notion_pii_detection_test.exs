defmodule PiiGuardian.NotionPiiDetectionTest do
  use PiiGuardian.DataCase, async: false

  import Mox

  alias PiiGuardian.MockAnthropix
  alias PiiGuardian.MockNotionApi
  alias PiiGuardian.NotionPiiDetection

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Allow mocks to be called from any process
  setup do
    Mox.set_mox_global()
    :ok
  end

  describe "detect_pii_in_page/1" do
    test "returns :safe when no PII is detected in text blocks" do
      page_id = "fake-page-id-12345"

      # Mock NotionApi.get_all_page_content to return page blocks
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{
               "rich_text" => [
                 %{"type" => "text", "text" => %{"content" => "This is safe content."}}
               ]
             }
           },
           %{
             "type" => "heading_1",
             "heading_1" => %{
               "rich_text" => [%{"type" => "text", "text" => %{"content" => "Safe Heading"}}]
             }
           }
         ]}
      end)

      # Mock Anthropix for text check
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] Content is safe"}]}}
      end)

      assert NotionPiiDetection.detect_pii_in_page(page_id) == :safe
    end

    test "returns :safe when page has no text content but has safe files" do
      page_id = "fake-page-id-12345"

      # Mock NotionApi.get_all_page_content to return page with only file blocks (no text)
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{
             "id" => "file-block-id",
             "type" => "file",
             "file" => %{
               "type" => "external",
               "external" => %{"url" => "https://example.com/safe-file.pdf"}
             }
           }
         ]}
      end)

      # Mock NotionApi.download_file
      expect(MockNotionApi, :download_file, fn "https://example.com/safe-file.pdf" ->
        {:ok, %{body: "safe file content", mimetype: "application/pdf"}}
      end)

      # Mock Anthropix for file check
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] File content is safe"}]}}
      end)

      assert NotionPiiDetection.detect_pii_in_page(page_id) == :safe
    end

    test "returns :safe when no text or file blocks are present" do
      page_id = "fake-page-id-12345"

      # Mock NotionApi.get_all_page_content to return page with no text or file blocks
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{"type" => "divider"},
           %{"type" => "table_of_contents"}
         ]}
      end)

      assert NotionPiiDetection.detect_pii_in_page(page_id) == :safe
    end

    test "returns {:unsafe, page_id, explanation} when text contains PII" do
      page_id = "fake-page-id-12345"
      explanation = "Contains SSN and phone numbers"

      # Mock NotionApi.get_all_page_content to return page blocks with PII
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{
               "rich_text" => [%{"type" => "text", "text" => %{"content" => "SSN: 123-45-6789"}}]
             }
           }
         ]}
      end)

      # Mock Anthropix for text check
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] #{explanation}"}]}}
      end)

      assert NotionPiiDetection.detect_pii_in_page(page_id) == {:unsafe, page_id, explanation}
    end

    test "returns {:unsafe, page_id, [%{block_id, explanation}]} when file contains PII" do
      page_id = "fake-page-id-12345"
      block_id = "file-block-id"
      file_explanation = "PDF contains credit card numbers"

      # Mock NotionApi.get_all_page_content
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:ok,
         [
           %{
             "type" => "paragraph",
             "paragraph" => %{
               "rich_text" => [%{"type" => "text", "text" => %{"content" => "Safe text"}}]
             }
           },
           %{
             "id" => block_id,
             "type" => "file",
             "file" => %{
               "type" => "external",
               "external" => %{"url" => "https://example.com/unsafe-file.pdf"}
             }
           }
         ]}
      end)

      # Mock Anthropix for text check (safe)
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] Text content is safe"}]}}
      end)

      # Mock NotionApi.download_file
      expect(MockNotionApi, :download_file, fn "https://example.com/unsafe-file.pdf" ->
        {:ok, %{body: "file with PII content", mimetype: "application/pdf"}}
      end)

      # Mock Anthropix for file check (unsafe)
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] #{file_explanation}"}]}}
      end)

      expected_result = {:unsafe, page_id, [%{block_id: block_id, explanation: file_explanation}]}
      assert NotionPiiDetection.detect_pii_in_page(page_id) == expected_result
    end

    test "returns error result when page content can't be retrieved" do
      page_id = "fake-page-id-12345"

      # Mock NotionApi.get_all_page_content to return error
      expect(MockNotionApi, :get_all_page_content, fn ^page_id ->
        {:error, "Access denied"}
      end)

      expected = {:unsafe, page_id, "Failed to retrieve page content: Access denied"}

      captured_log =
        capture_log([level: :error], fn ->
          assert NotionPiiDetection.detect_pii_in_page(page_id) == expected
        end)

      assert captured_log =~
               "Failed to retrieve content for page ID: fake-page-id-12345, reason: Access denied"
    end
  end

  describe "detect_pii_in_block/1" do
    test "returns :safe for text block without PII" do
      block_id = "block-id-12345"

      # Mock NotionApi.get_block to return block
      expect(MockNotionApi, :get_block, fn ^block_id ->
        {:ok,
         %{
           "type" => "paragraph",
           "paragraph" => %{
             "rich_text" => [%{"type" => "text", "text" => %{"content" => "Safe content"}}]
           }
         }}
      end)

      # Mock Anthropix for text check
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] Content is safe"}]}}
      end)

      assert NotionPiiDetection.detect_pii_in_block(block_id) == :safe
    end

    test "returns {:unsafe, block_id, explanation} for text block with PII" do
      block_id = "block-id-12345"
      explanation = "Contains email addresses"

      # Mock NotionApi.get_block to return block
      expect(MockNotionApi, :get_block, fn ^block_id ->
        {:ok,
         %{
           "type" => "paragraph",
           "paragraph" => %{
             "rich_text" => [
               %{"type" => "text", "text" => %{"content" => "Email: test@example.com"}}
             ]
           }
         }}
      end)

      # Mock Anthropix for text check
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] #{explanation}"}]}}
      end)

      assert NotionPiiDetection.detect_pii_in_block(block_id) == {:unsafe, block_id, explanation}
    end

    test "returns :safe for non-text and non-file block" do
      block_id = "block-id-12345"

      # Mock NotionApi.get_block to return a divider block
      expect(MockNotionApi, :get_block, fn ^block_id ->
        {:ok, %{"type" => "divider"}}
      end)

      assert NotionPiiDetection.detect_pii_in_block(block_id) == :safe
    end

    test "returns :safe for file block with safe content" do
      block_id = "block-id-12345"

      # Mock NotionApi.get_block to return file block
      expect(MockNotionApi, :get_block, fn ^block_id ->
        {:ok,
         %{
           "id" => block_id,
           "type" => "file",
           "file" => %{
             "type" => "external",
             "external" => %{"url" => "https://example.com/safe-file.pdf"}
           }
         }}
      end)

      # Mock NotionApi.download_file
      expect(MockNotionApi, :download_file, fn "https://example.com/safe-file.pdf" ->
        {:ok, %{body: "safe file content", mimetype: "application/pdf"}}
      end)

      # Mock Anthropix for file check
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] File content is safe"}]}}
      end)

      assert NotionPiiDetection.detect_pii_in_block(block_id) == :safe
    end

    test "returns {:unsafe, block_id, explanation} for file block with PII" do
      block_id = "block-id-12345"
      explanation = "File contains SSN"

      # Mock NotionApi.get_block to return file block
      expect(MockNotionApi, :get_block, fn ^block_id ->
        {:ok,
         %{
           "id" => block_id,
           "type" => "file",
           "file" => %{
             "type" => "file",
             "file" => %{"url" => "https://example.com/unsafe-file.pdf"}
           }
         }}
      end)

      # Mock NotionApi.download_file
      expect(MockNotionApi, :download_file, fn "https://example.com/unsafe-file.pdf" ->
        {:ok, %{body: "file with PII", mimetype: "application/pdf"}}
      end)

      # Mock Anthropix for file check
      MockAnthropix
      |> expect(:init, fn _api_key -> %{client: :test_client} end)
      |> expect(:chat, fn _client, _opts ->
        {:ok, %{"content" => [%{"text" => "[YES_PII_UNSAFE] #{explanation}"}]}}
      end)

      assert NotionPiiDetection.detect_pii_in_block(block_id) == {:unsafe, block_id, explanation}
    end

    test "returns {:unsafe, block_id, explanation} when file download fails" do
      block_id = "block-id-12345"

      # Mock NotionApi.get_block to return file block
      expect(MockNotionApi, :get_block, fn ^block_id ->
        {:ok,
         %{
           "id" => block_id,
           "type" => "image",
           "image" => %{
             "type" => "external",
             "external" => %{"url" => "https://example.com/image.jpg"}
           }
         }}
      end)

      # Mock NotionApi.download_file to fail
      expect(MockNotionApi, :download_file, fn "https://example.com/image.jpg" ->
        {:error, "Download failed: 404 Not Found"}
      end)

      expected =
        {:unsafe, block_id,
         "Failed to download file for PII analysis: Download failed: 404 Not Found"}

      captured_log =
        capture_log([level: :error], fn ->
          assert NotionPiiDetection.detect_pii_in_block(block_id) == expected
        end)

      assert captured_log =~ "Failed to download file: Download failed: 404 Not Found"
    end

    test "returns {:unsafe, block_id, explanation} when file URL can't be found" do
      block_id = "block-id-12345"

      # Mock NotionApi.get_block to return file block with missing URL
      expect(MockNotionApi, :get_block, fn ^block_id ->
        {:ok,
         %{
           "id" => block_id,
           "type" => "file",
           # No URL info
           "file" => %{"type" => "invalid_type"}
         }}
      end)

      expected = {:unsafe, block_id, "No file URL found in block"}

      captured_log =
        capture_log([level: :error], fn ->
          assert NotionPiiDetection.detect_pii_in_block(block_id) == expected
        end)

      assert captured_log =~ "No file URL found in block: block-id-12345"
    end

    test "returns error result when block can't be retrieved" do
      block_id = "block-id-12345"

      # Mock NotionApi.get_block to return error
      expect(MockNotionApi, :get_block, fn ^block_id ->
        {:error, "Block not found"}
      end)

      expected = {:unsafe, block_id, "Failed to retrieve block content: Block not found"}

      captured_log =
        capture_log([level: :error], fn ->
          assert NotionPiiDetection.detect_pii_in_block(block_id) == expected
        end)

      assert captured_log =~ "Failed to retrieve block: block-id-12345, reason: Block not found"
    end
  end

  describe "extract_text_from_block/1" do
    test "extracts text from various block types" do
      # This test exercises the private extract_text_from_block function
      # through the public detect_pii_in_block function

      # Test different block types
      block_types = [
        "paragraph",
        "heading_1",
        "heading_2",
        "heading_3",
        "bulleted_list_item",
        "numbered_list_item",
        "to_do",
        "toggle",
        "quote",
        "callout",
        "code"
      ]

      Enum.each(block_types, fn block_type ->
        block_id = "block-id-#{block_type}"

        # Create block structure
        block = %{
          "id" => block_id,
          "type" => block_type,
          block_type => %{
            "rich_text" => [
              %{"type" => "text", "text" => %{"content" => "Text from #{block_type}"}}
            ]
          }
        }

        # Mock NotionApi.get_block to return this specific block type
        expect(MockNotionApi, :get_block, fn ^block_id ->
          {:ok, block}
        end)

        # Mock Anthropix for text check
        MockAnthropix
        |> expect(:init, fn _api_key -> %{client: :test_client} end)
        |> expect(:chat, fn _client, opts ->
          # Verify that the correct text is being sent to Anthropic
          messages = Keyword.get(opts, :messages, [])
          text = hd(messages)[:content]
          assert text == "Text from #{block_type}"

          {:ok, %{"content" => [%{"text" => "[NO_PII_SAFE] Content is safe"}]}}
        end)

        # Test the function with this block type
        assert NotionPiiDetection.detect_pii_in_block(block_id) == :safe
      end)
    end
  end
end
