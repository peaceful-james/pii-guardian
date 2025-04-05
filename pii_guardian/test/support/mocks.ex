defmodule PiiGuardian.Mocks do
  @moduledoc """
  Defines mock modules for testing using Mox.
  """

  defmodule AnthropixBehaviour do
    @moduledoc """
    Behavior for Anthropix module.
    """
    @callback init(api_key :: String.t()) :: map()
    @callback chat(client :: map(), opts :: Keyword.t()) :: {:ok, map()} | {:error, any()}
  end

  # Define the behavior modules for our mocks
  defmodule SlackApiBehaviour do
    @moduledoc """
    Behavior for SlackApi module.
    """
    @callback lookup_user_by_email(email :: String.t()) :: {:ok, map()} | {:error, any()}
    @callback get_user_info(user_id :: String.t()) :: {:ok, map()} | {:error, any()}
    @callback open_dm(user_id :: String.t()) :: {:ok, map()} | {:error, any()}
    @callback post_message(channel :: String.t(), text :: String.t(), opts :: map()) ::
                {:ok, map()} | {:error, any()}
    @callback delete_message(channel :: String.t(), ts :: String.t()) ::
                {:ok, map()} | {:error, any()}
    @callback delete_file(file_id :: String.t()) :: {:ok, map()} | {:error, any()}
    @callback download_file(url :: String.t()) ::
                {:ok, %{body: binary(), headers: list()}} | {:error, any()}
    @callback list_users(cursor :: String.t() | nil, limit :: integer()) ::
                {:ok, map()} | {:error, any()}
    @callback get_file_info(file_id :: String.t()) :: {:ok, map()} | {:error, any()}
  end

  defmodule NotionApiBehaviour do
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
    @callback list_users(cursor :: String.t() | nil, page_size :: integer()) ::
                {:ok, map()} | {:error, any()}
    @callback get_all_users() :: {:ok, list()} | {:error, any()}
    @callback download_file(url :: String.t()) :: {:ok, binary()} | {:error, any()}
  end

  defmodule AnthropicPiiDetectionBehaviour do
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
end

# Define the mocks using Mox
# Mox.defmock(PiiGuardian.MockSlackApi, for: PiiGuardian.Mocks.SlackApiBehaviour)
# Mox.defmock(PiiGuardian.MockNotionApi, for: PiiGuardian.Mocks.NotionApiBehaviour)

# Mox.defmock(PiiGuardian.MockAnthropicPiiDetection,
# for: PiiGuardian.Mocks.AnthropicPiiDetectionBehaviour
# )
