defmodule PiiGuardian.Repo do
  use Ecto.Repo,
    otp_app: :pii_guardian,
    adapter: Ecto.Adapters.Postgres
end
