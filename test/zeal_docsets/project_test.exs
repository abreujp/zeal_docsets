defmodule ZealDocsets.ProjectTest do
  use ExUnit.Case, async: false

  alias ZealDocsets.Project

  setup do
    project_root =
      Path.join(System.tmp_dir!(), "zeal_docsets_fixture_#{System.unique_integer([:positive])}")

    File.mkdir_p!(project_root)

    on_exit(fn -> File.rm_rf(project_root) end)

    %{project_root: project_root}
  end

  test "loads direct hex deps with locked versions", %{project_root: project_root} do
    write_fixture_project(project_root)

    deps = Project.load!(project_root)

    assert Enum.map(deps, &{&1.package, &1.version}) == [
             {"ecto", "3.13.5"},
             {"phoenix", "1.8.4"}
           ]
  end

  test "excludes git deps", %{project_root: project_root} do
    write_fixture_project(project_root)
    packages = Project.load!(project_root) |> Enum.map(& &1.package)
    refute "heroicons" in packages
  end

  test "excludes dev-only deps by default", %{project_root: project_root} do
    write_fixture_project(project_root)
    packages = Project.load!(project_root) |> Enum.map(& &1.package)
    refute "credo" in packages
  end

  test "includes dev deps when include_dev: true", %{project_root: project_root} do
    write_fixture_project(project_root)

    deps = Project.load!(project_root, include_dev: true)

    assert {"credo", "1.7.12"} in Enum.map(deps, &{&1.package, &1.version})
  end

  test "excludes test-only deps by default", %{project_root: project_root} do
    write_fixture_project(project_root)
    packages = Project.load!(project_root) |> Enum.map(& &1.package)
    refute "floki" in packages
  end

  test "includes test deps when include_test: true", %{project_root: project_root} do
    write_fixture_project(project_root)

    deps = Project.load!(project_root, include_test: true)

    assert {"floki", "0.38.0"} in Enum.map(deps, &{&1.package, &1.version})
  end

  test "raises ArgumentError when mix.exs is missing", %{project_root: project_root} do
    assert_raise ArgumentError, ~r/mix\.exs/, fn ->
      Project.load!(project_root)
    end
  end

  defp write_fixture_project(project_root) do
    module_name = "FixtureProject#{System.unique_integer([:positive])}.MixProject"

    File.write!(
      Path.join(project_root, "mix.exs"),
      """
      defmodule #{module_name} do
        use Mix.Project

        def project do
          [
            app: :fixture_project,
            version: \"0.1.0\",
            elixir: \"~> 1.19\",
            deps: deps()
          ]
        end

        def application do
          [extra_applications: [:logger]]
        end

        defp deps do
          [
            {:phoenix, \"~> 1.8\"},
            {:ecto, \"~> 3.13\"},
            {:credo, \"~> 1.7\", only: [:dev, :test]},
            {:floki, \">= 0.37.0\", only: :test},
            {:heroicons, git: \"https://github.com/tailwindlabs/heroicons.git\", tag: \"v2.2.0\"}
          ]
        end
      end
      """
    )

    File.write!(
      Path.join(project_root, "mix.lock"),
      """
      %{
        credo: {:hex, :credo, \"1.7.12\", \"checksum\", [:mix], [], \"hexpm\", \"outer\"},
        ecto: {:hex, :ecto, \"3.13.5\", \"checksum\", [:mix], [], \"hexpm\", \"outer\"},
        floki: {:hex, :floki, \"0.38.0\", \"checksum\", [:mix], [], \"hexpm\", \"outer\"},
        phoenix: {:hex, :phoenix, \"1.8.4\", \"checksum\", [:mix], [], \"hexpm\", \"outer\"},
        heroicons: {:git, \"https://github.com/tailwindlabs/heroicons.git\", \"sha\", [tag: \"v2.2.0\"]}
      }
      """
    )
  end
end
