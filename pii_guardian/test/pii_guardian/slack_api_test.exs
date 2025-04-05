defmodule PiiGuardian.SlackApiTest do
  use ExUnit.Case, async: true

  import Tesla.Mock
  import ExUnit.CaptureLog

  alias PiiGuardian.SlackApi

  # Helper to return JSON responses with status 200
  defp build_json_env(body) do
    %Tesla.Env{
      status: 200,
      body: body,
      headers: [{"content-type", "application/json"}]
    }
  end

  # Setup application environment for testing
  setup_all do
    # Set required configuration for the SlackApi module
    Application.put_env(:pii_guardian, PiiGuardian.Slackbot, bot_token: "xoxb-test-bot-token")
    Application.put_env(:slack_elixir, :admin_user_token, "xoxp-test-admin-token")
    :ok
  end

  describe "get_file_info/1" do
    test "returns file data when request is successful" do
      file_id = "F12345"

      mock(fn
        %{method: :get, url: "https://slack.com/api/files.info", query: [file: ^file_id]} ->
          build_json_env(%{
            "ok" => true,
            "file" => %{
              "id" => file_id,
              "name" => "test.txt",
              "mimetype" => "text/plain"
            }
          })
      end)

      assert {:ok, response} = SlackApi.get_file_info(file_id)
      assert response["ok"] == true
      assert response["file"]["id"] == file_id
      assert response["file"]["name"] == "test.txt"
    end

    test "returns error when API returns non-ok status" do
      file_id = "INVALID"

      mock(fn
        %{method: :get, url: "https://slack.com/api/files.info", query: [file: ^file_id]} ->
          build_json_env(%{
            "ok" => false,
            "error" => "file_not_found"
          })
      end)

      log =
        capture_log(fn ->
          assert {:error, error} = SlackApi.get_file_info(file_id)
          assert error == "file_not_found"
        end)

      assert log =~ "TODO_FOR_DEV"
    end

    test "returns error when HTTP request fails" do
      file_id = "F_HTTP_ERROR"

      mock(fn
        %{method: :get, url: "https://slack.com/api/files.info", query: [file: ^file_id]} ->
          %Tesla.Env{
            status: 404,
            body: "Not found"
          }
      end)

      log =
        capture_log(fn ->
          assert {:error, error} = SlackApi.get_file_info(file_id)
          assert error =~ "HTTP error 404"
        end)

      assert log =~ "TODO_FOR_DEV"
    end

    test "returns error when client error occurs" do
      file_id = "F_CLIENT_ERROR"

      mock(fn
        %{method: :get, url: "https://slack.com/api/files.info", query: [file: ^file_id]} ->
          {:error, :timeout}
      end)

      log =
        capture_log(fn ->
          assert {:error, error} = SlackApi.get_file_info(file_id)
          assert error =~ "Client error: :timeout"
        end)

      assert log =~ "TODO_FOR_DEV"
    end
  end

  describe "delete_message/2" do
    test "deletes a message successfully" do
      channel = "C12345"
      ts = "1234567890.123456"

      mock(fn
        %{
          method: :post,
          url: "https://slack.com/api/chat.delete",
          body: %{channel: ^channel, ts: ^ts}
        } ->
          build_json_env(%{
            "ok" => true,
            "channel" => channel,
            "ts" => ts
          })
      end)

      assert {:ok, response} = SlackApi.delete_message(channel, ts)
      assert response["ok"] == true
      assert response["channel"] == channel
      assert response["ts"] == ts
    end

    test "returns error when delete fails" do
      channel = "C12345"
      ts = "invalid"

      mock(fn
        %{
          method: :post,
          url: "https://slack.com/api/chat.delete",
          body: %{channel: ^channel, ts: ^ts}
        } ->
          build_json_env(%{
            "ok" => false,
            "error" => "message_not_found"
          })
      end)

      log =
        capture_log(fn ->
          assert {:error, error} = SlackApi.delete_message(channel, ts)
          assert error == "message_not_found"
        end)

      assert log =~ "TODO_FOR_DEV"
    end
  end

  describe "post_message/3" do
    test "posts a message with default options" do
      channel = "C12345"
      text = "Hello world"

      mock(fn
        %{
          method: :post,
          url: "https://slack.com/api/chat.postMessage",
          body: %{channel: ^channel, text: ^text}
        } ->
          build_json_env(%{
            "ok" => true,
            "channel" => channel,
            "ts" => "1234567890.123456",
            "message" => %{"text" => text}
          })
      end)

      assert {:ok, response} = SlackApi.post_message(channel, text)
      assert response["ok"] == true
      assert response["channel"] == channel
      assert response["message"]["text"] == text
    end

    test "posts a message with custom options" do
      channel = "C12345"
      text = "Hello world"
      opts = %{as_user: true, link_names: 1}

      mock(fn
        %{method: :post, url: "https://slack.com/api/chat.postMessage", body: body} ->
          assert %{
                   "channel" => ^channel,
                   "text" => ^text,
                   "as_user" => true,
                   "link_names" => 1
                 } = JSON.decode!(body)

          build_json_env(%{
            "ok" => true,
            "channel" => channel,
            "ts" => "1234567890.123456",
            "message" => %{"text" => text}
          })
      end)

      assert {:ok, response} = SlackApi.post_message(channel, text, opts)
      assert response["ok"] == true
    end

    test "returns error when post fails" do
      channel = "INVALID"
      text = "Hello world"

      mock(fn
        %{
          method: :post,
          url: "https://slack.com/api/chat.postMessage",
          body: %{channel: ^channel, text: ^text}
        } ->
          build_json_env(%{
            "ok" => false,
            "error" => "channel_not_found"
          })
      end)

      log =
        capture_log(fn ->
          assert {:error, error} = SlackApi.post_message(channel, text)
          assert error == "channel_not_found"
        end)

      assert log =~ "TODO_FOR_DEV"
    end
  end

  describe "open_dm/1" do
    test "opens a DM channel successfully" do
      user_id = "U12345"

      mock(fn
        %{
          method: :post,
          url: "https://slack.com/api/conversations.open",
          body: %{users: ^user_id}
        } ->
          build_json_env(%{
            "ok" => true,
            "channel" => %{
              "id" => "D12345",
              "is_im" => true
            }
          })
      end)

      assert {:ok, response} = SlackApi.open_dm(user_id)
      assert response["ok"] == true
      assert response["channel"]["id"] == "D12345"
      assert response["channel"]["is_im"] == true
    end

    test "returns error when open_dm fails" do
      user_id = "INVALID"
      encoded_body = JSON.encode!(%{users: user_id})

      mock(fn
        %{
          method: :post,
          url: "https://slack.com/api/conversations.open",
          body: ^encoded_body
        } ->
          build_json_env(%{
            "ok" => false,
            "error" => "user_not_found"
          })
      end)

      log =
        capture_log(fn ->
          assert {:error, error} = SlackApi.open_dm(user_id)
          assert error == "user_not_found"
        end)

      assert log =~ ~s(Slack API error: %{\"error\" => \"user_not_found\", \"ok\" => false})
    end
  end

  describe "delete_file/1" do
    test "deletes a file successfully" do
      file_id = "F12345"

      mock(fn
        %{method: :post, url: "https://slack.com/api/files.delete", body: %{file: ^file_id}} ->
          build_json_env(%{
            "ok" => true
          })
      end)

      assert {:ok, response} = SlackApi.delete_file(file_id)
      assert response["ok"] == true
    end

    test "returns error when delete_file fails" do
      file_id = "INVALID"

      mock(fn
        %{method: :post, url: "https://slack.com/api/files.delete", body: %{file: ^file_id}} ->
          build_json_env(%{
            "ok" => false,
            "error" => "file_not_found"
          })
      end)

      log =
        capture_log(fn ->
          assert {:error, error} = SlackApi.delete_file(file_id)
          assert error == "file_not_found"
        end)

      assert log =~ "TODO_FOR_DEV"
    end
  end

  describe "lookup_user_by_email/1" do
    test "looks up a user by email successfully" do
      email = "user@example.com"

      mock(fn
        %{method: :get, url: "https://slack.com/api/users.lookupByEmail", query: [email: ^email]} ->
          build_json_env(%{
            "ok" => true,
            "user" => %{
              "id" => "U12345",
              "name" => "testuser",
              "profile" => %{
                "email" => email
              }
            }
          })
      end)

      assert {:ok, response} = SlackApi.lookup_user_by_email(email)
      assert response["ok"] == true
      assert response["user"]["id"] == "U12345"
      assert response["user"]["profile"]["email"] == email
    end

    test "returns error when user not found" do
      email = "nonexistent@example.com"

      mock(fn
        %{method: :get, url: "https://slack.com/api/users.lookupByEmail", query: [email: ^email]} ->
          build_json_env(%{
            "ok" => false,
            "error" => "users_not_found"
          })
      end)

      log =
        capture_log(fn ->
          assert {:error, error} = SlackApi.lookup_user_by_email(email)
          assert error == "users_not_found"
        end)

      assert log =~ "TODO_FOR_DEV"
    end
  end

  describe "get_user_info/1" do
    test "gets user info successfully" do
      user_id = "U12345"

      mock(fn
        %{method: :get, url: "https://slack.com/api/users.info", query: [user: ^user_id]} ->
          build_json_env(%{
            "ok" => true,
            "user" => %{
              "id" => user_id,
              "name" => "testuser",
              "profile" => %{
                "real_name" => "Test User"
              }
            }
          })
      end)

      assert {:ok, response} = SlackApi.get_user_info(user_id)
      assert response["ok"] == true
      assert response["user"]["id"] == user_id
      assert response["user"]["profile"]["real_name"] == "Test User"
    end

    test "returns error when user not found" do
      user_id = "INVALID"

      mock(fn
        %{method: :get, url: "https://slack.com/api/users.info", query: [user: ^user_id]} ->
          build_json_env(%{
            "ok" => false,
            "error" => "user_not_found"
          })
      end)

      log =
        capture_log(fn ->
          assert {:error, error} = SlackApi.get_user_info(user_id)
          assert error == "user_not_found"
        end)

      assert log =~ "TODO_FOR_DEV"
    end
  end

  describe "download_file/1" do
    test "downloads a file successfully" do
      url = "https://files.slack.com/files-pri/T12345-F12345/file.txt"

      mock(fn
        %{method: :get, url: ^url} ->
          %Tesla.Env{
            status: 200,
            body: "File content",
            headers: [{"content-type", "text/plain"}]
          }
      end)

      assert {:ok, response} = SlackApi.download_file(url)
      assert response.status == 200
      assert response.body == "File content"
    end

    test "returns error when download fails" do
      url = "https://files.slack.com/files-pri/T12345-INVALID/file.txt"

      mock(fn
        %{method: :get, url: ^url} ->
          %Tesla.Env{
            status: 404,
            body: "Not found"
          }
      end)

      assert {:error, response} = SlackApi.download_file(url)
      assert response.status == 404
    end

    test "handles network errors" do
      url = "https://files.slack.com/network-error"

      mock(fn
        %{method: :get, url: ^url} ->
          {:error, :timeout}
      end)

      assert {:error, :timeout} = SlackApi.download_file(url)
    end
  end
end
