defmodule PiiGuardian.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PiiGuardianWeb.Telemetry,
      PiiGuardian.Repo,
      {DNSCluster, query: Application.get_env(:pii_guardian, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PiiGuardian.PubSub},
      # Start a worker by calling: PiiGuardian.Worker.start_link(arg)
      # {PiiGuardian.Worker, arg},
      # Start to serve requests, typically the last entry
      PiiGuardianWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PiiGuardian.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PiiGuardianWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
