defmodule PIIGuardian do
  @moduledoc """
  PIIGuardian monitors Slack channels and Notion databases for PII information.
  
  When PII is detected, the content is removed and the author is notified.
  """

  @doc """
  Returns the application version
  """
  def version do
    Application.spec(:pii_guardian, :vsn)
  end
end
