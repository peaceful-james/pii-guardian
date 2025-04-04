defmodule PIIGuardian.MixProject do
  use Mix.Project

  def project do
    [
      app: :pii_guardian,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  def application do
    [
      mod: {PIIGuardian.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  defp deps do
    [
      # Slack API client
      {:slack, "~> 0.23.5"},
      
      # HTTP client
      {:finch, "~> 0.13"},
      {:tesla, "~> 1.4"},
      
      # JSON parser
      {:jason, "~> 1.2"},
      
      # Background job processing
      {:oban, "~> 2.13"},
      
      # Database
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0"},
      
      # PDF processing
      {:pdf, "~> 0.6.0"},
      
      # Testing
      {:mock, "~> 0.3.0", only: :test},
      {:ex_machina, "~> 2.7.0", only: :test},
      
      # Development tools
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
