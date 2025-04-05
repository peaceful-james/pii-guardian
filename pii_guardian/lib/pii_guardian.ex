defmodule PiiGuardian do
  @moduledoc """
  PiiGuardian keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  @env Application.compile_env(:pii_guardian, :env)
  @spec env() :: :dev | :test | :prod
  def env, do: Application.get_env(:pii_guardian, :env) || @env
end
