defmodule PiiGuardian.SlackEventMocks do
  @moduledoc """
   Mocks for Slack events. These are used in tests to simulate Slack events.
  """

  defmodule Safe do
    @moduledoc false
    def new_message do
      %{
        "blocks" => [
          %{
            "block_id" => "XXXXXX",
            "elements" => [
              %{
                "elements" => [%{"text" => "yes", "type" => "text"}],
                "type" => "rich_text_section"
              }
            ],
            "type" => "rich_text"
          }
        ],
        "channel" => "CXXXXXXXXXX",
        "channel_type" => "channel",
        "client_msg_id" => "fake-client-msg-id-abcdef",
        "event_ts" => "1743806350.485119",
        "team" => "TXXXXXXXXXX",
        "text" => "yes",
        "ts" => "1743806350.485119",
        "type" => "message",
        "user" => "UXXXXXXXXXX"
      }
    end

    def edited_message do
      %{
        "channel" => "CXXXXXXXXXX",
        "channel_type" => "channel",
        "event_ts" => "1743806452.001200",
        "hidden" => true,
        "message" => %{
          "blocks" => [
            %{
              "block_id" => "XXXXXX",
              "elements" => [
                %{
                  "elements" => [%{"text" => "hello again", "type" => "text"}],
                  "type" => "rich_text_section"
                }
              ],
              "type" => "rich_text"
            }
          ],
          "client_msg_id" => "fake-client-msg-id-123456",
          "edited" => %{"ts" => "1743806452.000000", "user" => "UXXXXXXXXXX"},
          "is_locked" => false,
          "latest_reply" => "1743789529.806319",
          "reply_count" => 2,
          "reply_users" => ["UXXXXXXXXXX"],
          "reply_users_count" => 1,
          "source_team" => "TXXXXXXXXXX",
          "team" => "TXXXXXXXXXX",
          "text" => "hello again",
          "thread_ts" => "1743789192.312789",
          "ts" => "1743789192.312789",
          "type" => "message",
          "user" => "UXXXXXXXXXX",
          "user_team" => "TXXXXXXXXXX"
        },
        "previous_message" => %{
          "blocks" => [
            %{
              "block_id" => "XXXXXX",
              "elements" => [
                %{
                  "elements" => [%{"text" => "hello", "type" => "text"}],
                  "type" => "rich_text_section"
                }
              ],
              "type" => "rich_text"
            }
          ],
          "client_msg_id" => "fake-client-msg-id-123456",
          "is_locked" => false,
          "last_read" => "1743789529.806319",
          "latest_reply" => "1743789529.806319",
          "reply_count" => 2,
          "reply_users" => ["UXXXXXXXXXX"],
          "reply_users_count" => 1,
          "subscribed" => true,
          "team" => "TXXXXXXXXXX",
          "text" => "hello",
          "thread_ts" => "1743789192.312789",
          "ts" => "1743789192.312789",
          "type" => "message",
          "user" => "UXXXXXXXXXX"
        },
        "subtype" => "message_changed",
        "ts" => "1743806452.001200",
        "type" => "message"
      }
    end

    def new_thread_message_with_attachment do
      %{
        "accepts_response_payload" => false,
        "envelope_id" => "fake-envelope-id-123456-abcdef",
        "payload" => %{
          "api_app_id" => "AXXXXXXXXXX",
          "authorizations" => [
            %{
              "enterprise_id" => nil,
              "is_bot" => false,
              "is_enterprise_install" => false,
              "team_id" => "TXXXXXXXXXX",
              "user_id" => "UXXXXXXXXXX"
            }
          ],
          "context_enterprise_id" => nil,
          "context_team_id" => "TXXXXXXXXXX",
          "event" => %{
            "blocks" => [
              %{
                "block_id" => "XXXXXX",
                "elements" => [
                  %{
                    "elements" => [%{"text" => "have a text file", "type" => "text"}],
                    "type" => "rich_text_section"
                  }
                ],
                "type" => "rich_text"
              }
            ],
            "channel" => "CXXXXXXXXXX",
            "channel_type" => "channel",
            "client_msg_id" => "fake-client-msg-id-123456",
            "display_as_bot" => false,
            "event_ts" => "1743789529.806319",
            "files" => [
              %{
                "created" => 1_743_789_528,
                "display_as_bot" => false,
                "edit_link" =>
                  "https://fake-workspace.slack.com/files/UXXXXXXXXXX/FXXXXXXXXXX/attachment.txt/edit",
                "editable" => true,
                "external_type" => "",
                "file_access" => "visible",
                "filetype" => "text",
                "has_rich_preview" => false,
                "id" => "FXXXXXXXXXX",
                "is_external" => false,
                "is_public" => true,
                "lines" => 1,
                "lines_more" => 0,
                "mimetype" => "text/plain",
                "mode" => "snippet",
                "name" => "attachment.txt",
                "permalink" =>
                  "https://fake-workspace.slack.com/files/UXXXXXXXXXX/FXXXXXXXXXX/attachment.txt",
                "permalink_public" => "https://slack-files.com/TXXXXXXXXXX-FXXXXXXXXXX-abcd1234",
                "pretty_type" => "Plain Text",
                "preview" => "These characters live in a text file. How pleasant.",
                "preview_highlight" =>
                  "<div class=\"CodeMirror cm-s-default CodeMirrorServer\">\n<div class=\"CodeMirror-code\">\n<div><pre>These characters live in a text file. How pleasant.</pre></div>\n</div>\n</div>\n",
                "preview_is_truncated" => false,
                "public_url_shared" => false,
                "size" => 51,
                "timestamp" => 1_743_789_528,
                "title" => "attachment.txt",
                "url_private" =>
                  "https://files.slack.com/files-pri/TXXXXXXXXXX-FXXXXXXXXXX/attachment.txt",
                "url_private_download" =>
                  "https://files.slack.com/files-pri/TXXXXXXXXXX-FXXXXXXXXXX/download/attachment.txt",
                "user" => "UXXXXXXXXXX",
                "user_team" => "TXXXXXXXXXX",
                "username" => ""
              }
            ],
            "parent_user_id" => "UXXXXXXXXXX",
            "subtype" => "file_share",
            "text" => "have a text file",
            "thread_ts" => "1743789192.312789",
            "ts" => "1743789529.806319",
            "type" => "message",
            "upload" => false,
            "user" => "UXXXXXXXXXX"
          },
          "event_context" => "fake-event-context-123456",
          "event_id" => "EvXXXXXXXXXX",
          "event_time" => 1_743_789_529,
          "is_ext_shared_channel" => false,
          "team_id" => "TXXXXXXXXXX",
          "token" => "fake-token-123456",
          "type" => "event_callback"
        },
        "retry_attempt" => 0,
        "retry_reason" => "",
        "type" => "events_api"
      }
    end
  end

  defmodule Unsafe do
    @moduledoc false
    def new_message do
      %{
        "blocks" => [
          %{
            "block_id" => "XXXXXX",
            "elements" => [
              %{
                "elements" => [%{"text" => "[CONTAINS_PII]", "type" => "text"}],
                "type" => "rich_text_section"
              }
            ],
            "type" => "rich_text"
          }
        ],
        "channel" => "CXXXXXXXXXX",
        "channel_type" => "channel",
        "client_msg_id" => "fake-client-msg-id-abcdef",
        "event_ts" => "1743806350.485119",
        "team" => "TXXXXXXXXXX",
        "text" => "[CONTAINS_PII]",
        "ts" => "1743806350.485119",
        "type" => "message",
        "user" => "UXXXXXXXXXX"
      }
    end
  end
end
