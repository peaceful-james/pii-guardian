defmodule PiiGuardian.AnthropixBehaviour do
  @moduledoc """
  Behavior for Anthropix module.
  """
  @callback init(api_key :: String.t()) :: map()
  @callback chat(client :: map(), opts :: Keyword.t()) :: {:ok, map()} | {:error, any()}
end

defmodule PiiGuardian.SlackApiBehaviour do
  @moduledoc """
  Behavior for SlackApi module.
  """
  @callback lookup_user_by_email(email :: String.t()) :: {:ok, map()} | {:error, any()}
  @callback get_user_info(user_id :: String.t()) :: {:ok, map()} | {:error, any()}
  @callback open_dm(user_id :: String.t()) :: {:ok, map()} | {:error, any()}
  @callback post_message(channel :: String.t(), text :: String.t(), opts :: map()) ::
              {:ok, map()} | {:error, any()}
  # Add a function head for the 2-parameter version as well
  @callback post_message(channel :: String.t(), text :: String.t()) ::
              {:ok, map()} | {:error, any()}
  @callback delete_message(channel :: String.t(), ts :: String.t()) ::
              {:ok, map()} | {:error, any()}
  @callback delete_file(file_id :: String.t()) :: {:ok, map()} | {:error, any()}
  @callback download_file(url :: String.t()) ::
              {:ok, %{body: binary(), headers: list()}} | {:error, any()}
  @callback get_file_info(file_id :: String.t()) :: {:ok, map()} | {:error, any()}
end

defmodule PiiGuardian.SlackbotBehaviour do
  @moduledoc """
  Behavior for Slackbot module.
  """
  @callback delete_slack_message_and_dm_author(
              event :: map(),
              explanation :: String.t()
            ) :: :ok
  @callback delete_file_and_dm_author(
              file :: map(),
              event :: map(),
              explanation :: String.t()
            ) :: :ok
  @callback dm_author_about_notion_pii(
              email :: String.t(),
              page_id :: String.t(),
              page_title :: String.t(),
              explanation :: String.t()
            ) :: :ok | {:error, String.t()}
end

defmodule PiiGuardian.NotionApiBehaviour do
  @moduledoc """
  Behavior for NotionApi module.
  """
  @callback get_page(page_id :: String.t()) :: {:ok, map()} | {:error, any()}
  @callback get_page_content(
              page_id :: String.t(),
              cursor :: String.t() | nil,
              page_size :: integer()
            ) ::
              {:ok, map()} | {:error, any()}
  @callback get_all_page_content(page_id :: String.t()) :: {:ok, list()} | {:error, any()}
  @callback delete_page(page_id :: String.t()) :: {:ok, map()} | {:error, any()}
  @callback get_block(block_id :: String.t()) :: {:ok, map()} | {:error, any()}
  @callback delete_block(block_id :: String.t()) :: {:ok, map()} | {:error, any()}
  @callback get_user(user_id :: String.t()) :: {:ok, map()} | {:error, any()}
  @callback download_file(url :: String.t()) :: {:ok, binary()} | {:error, any()}
end

defmodule PiiGuardian.AnthropicPiiDetectionBehaviour do
  @moduledoc """
  Behavior for AnthropicPiiDetection module.
  """
  @callback detect_pii_in_text(text :: String.t() | nil) :: :safe | {:unsafe, String.t()}
  @callback detect_pii_in_file(
              content :: binary(),
              filetype :: String.t(),
              mimetype :: String.t()
            ) ::
              :safe | {:unsafe, String.t()}
end
