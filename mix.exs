defmodule ZealDocsets.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/abreujp/zeal_docsets"

  def project do
    [
      app: :zeal_docsets,
      version: @version,
      elixir: "~> 1.17",
      description: description(),
      package: package(),
      escript: escript(),
      homepage_url: @source_url,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      docs: docs(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      test_coverage: [
        # ZealDocsets.Hexdocs is excluded: it requires live network access
        # and is covered by integration tests only.
        ignore_modules: [ZealDocsets.Hexdocs, Mix.Tasks.Zeal.Docs]
      ],
      # Do not start the application for escript/tasks — no OTP app needed
      start_permanent: false
    ]
  end

  def application do
    [extra_applications: [:inets, :logger, :ssl]]
  end

  defp description do
    "Generate offline Zeal/Dash docsets from the direct Hex dependencies of any Mix project."
  end

  defp escript do
    [main_module: ZealDocsets.CLI]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      maintainers: ["João Paulo Abreu"],
      files: ~w(lib mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "ZealDocsets",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  def cli do
    [
      preferred_envs: [
        credo: :test,
        dialyzer: :test,
        doctor: :test,
        "deps.audit": :test,
        ex_dna: :test,
        quality: :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:exqlite, "~> 0.33"},
      {:floki, "~> 0.38"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:ex_slop, "~> 0.2", only: [:dev, :test], runtime: false},
      {:ex_dna, "~> 1.1", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      build: ["escript.build"],
      quality: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test",
        "credo --strict",
        "deps.audit",
        "doctor --summary",
        "ex_dna"
      ]
    ]
  end

  defp dialyzer do
    [
      plt_local_path: ".dialyzer",
      plt_add_apps: [:mix, :ex_unit],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end
end
