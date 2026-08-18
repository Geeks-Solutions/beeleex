defmodule Beeleex.MixProject do
  use Mix.Project

  def project do
    [
      app: :beeleex,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      package: package(),
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Beeleex.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:dev), do: ["lib", "dev/support"]
  defp elixirc_paths(:test), do: ["lib", "dev/support", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      files: ~w(lib dev/support priv mix.exs README.md docs)
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, ">= 1.6.15"},
      {:phoenix_live_view, "~> 0.20 or ~> 1.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:esbuild, "~> 0.8", runtime: false},
      {:telemetry_metrics, "~> 0.6 or ~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, ">= 0.18.0"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.5"},
      {:ex_geeks,
       git: "https://github.com/Geeks-Solutions/ex_geeks",
       ref: "9dfc2b93b2be6ac577a6643b230cb354abed7b1d"},
      # {:ex_geeks, path: "/Users/julien/Documents/Repos/Gitlab/Geeks/Libraries/ex_geeks"},
      {:floki, ">= 0.30.0", only: :test},
      {:mox, "~> 1.1", only: :test},

      # Code Quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"],
      q: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict"
      ]
    ]
  end
end
