defmodule ZealDocsets.RunnerTest do
  use ExUnit.Case, async: true

  alias ZealDocsets.Fixtures
  alias ZealDocsets.Runner

  describe "summarize/1" do
    test "counts built, skipped and failed correctly" do
      results = [
        {:ok, "phoenix", "/some/path"},
        {:ok, "ecto", "/other/path"},
        {:skipped, "plug", "/plug/path"},
        {:error, "broken", "some error"}
      ]

      assert Runner.summarize(results) == %{built: 2, skipped: 1, failed: 1}
    end

    test "returns zeros for empty list" do
      assert Runner.summarize([]) == %{built: 0, skipped: 0, failed: 0}
    end
  end

  describe "filter_packages/2" do
    setup do
      deps = [
        %ZealDocsets.Dep{app: :phoenix, package: "phoenix", version: "1.8.4"},
        %ZealDocsets.Dep{app: :ecto, package: "ecto", version: "3.13.5"},
        %ZealDocsets.Dep{app: :plug, package: "plug", version: "1.16.0"}
      ]

      {:ok, deps: deps}
    end

    test "returns all deps when filter list is empty", %{deps: deps} do
      assert Runner.filter_packages(deps, []) == deps
    end

    test "filters to requested packages only", %{deps: deps} do
      result = Runner.filter_packages(deps, ["phoenix", "plug"])
      assert Enum.map(result, & &1.package) == ["phoenix", "plug"]
    end

    test "returns empty list when no packages match", %{deps: deps} do
      assert Runner.filter_packages(deps, ["nonexistent"]) == []
    end
  end

  describe "default_workspace/0" do
    test "returns an absolute path under the system temp dir" do
      ws = Runner.default_workspace()
      assert Path.type(ws) == :absolute
      assert String.starts_with?(ws, System.tmp_dir!())
    end
  end

  describe "run/3" do
    setup do
      project_root =
        Path.join(
          System.tmp_dir!(),
          "zeal_runner_fixture_#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(project_root)
      write_fixture_project(project_root)

      on_exit(fn -> File.rm_rf!(project_root) end)
      {:ok, project_root: project_root}
    end

    test "returns run_result with correct shape", %{project_root: project_root} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = Path.join(base, "workspace")
        zeal_path = Path.join(base, "zeal")

        result =
          Runner.run(project_root, zeal_path,
            workspace: workspace,
            no_install: true,
            warn_missing_icon: false,
            mirror_fn: fake_mirror()
          )

        assert is_map(result)
        assert Map.has_key?(result, :project_path)
        assert Map.has_key?(result, :workspace)
        assert Map.has_key?(result, :zeal_path)
        assert Map.has_key?(result, :results)
        assert Map.has_key?(result, :summary)
        assert is_list(result.results)
      end)
    end

    test "builds docsets for all direct hex deps", %{project_root: project_root} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = Path.join(base, "workspace")
        zeal_path = Path.join(base, "zeal")

        result =
          Runner.run(project_root, zeal_path,
            workspace: workspace,
            no_install: true,
            warn_missing_icon: false,
            mirror_fn: fake_mirror()
          )

        packages = Enum.map(result.results, fn {_status, pkg, _path} -> pkg end)
        assert "mypkg" in packages
        assert result.summary == %{built: 1, skipped: 0, failed: 0}
      end)
    end

    test "respects --package filter", %{project_root: project_root} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = Path.join(base, "workspace")
        zeal_path = Path.join(base, "zeal")

        result =
          Runner.run(project_root, zeal_path,
            workspace: workspace,
            no_install: true,
            package: "mypkg",
            warn_missing_icon: false,
            mirror_fn: fake_mirror()
          )

        packages = Enum.map(result.results, fn {_status, pkg, _path} -> pkg end)
        assert packages == ["mypkg"]
      end)
    end

    test "returns include_dev and include_test flags in the result", %{project_root: project_root} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = Path.join(base, "workspace")
        zeal_path = Path.join(base, "zeal")

        result =
          Runner.run(project_root, zeal_path,
            workspace: workspace,
            no_install: true,
            dev: true,
            test: true,
            warn_missing_icon: false,
            mirror_fn: fake_mirror()
          )

        assert result.include_dev == true
        assert result.include_test == true
      end)
    end

    test "collects build failures instead of crashing", %{project_root: project_root} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = Path.join(base, "workspace")
        zeal_path = Path.join(base, "zeal")

        result =
          Runner.run(project_root, zeal_path,
            workspace: workspace,
            no_install: true,
            warn_missing_icon: false,
            mirror_fn: failing_mirror()
          )

        assert result.summary == %{built: 0, skipped: 0, failed: 1}
        assert [{:error, "mypkg", message}] = result.results
        assert message =~ "mirror failed"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp fake_mirror do
    fn pkg, version, downloads_root ->
      mirror_root = Path.join([downloads_root, pkg, version])
      File.rm_rf!(mirror_root)
      File.mkdir_p!(mirror_root)
      Fixtures.write_docs_fixture(mirror_root, pkg)
      mirror_root
    end
  end

  defp failing_mirror do
    fn _pkg, _version, _downloads_root ->
      raise "mirror failed"
    end
  end

  defp write_fixture_project(project_root) do
    module_name = "RunnerFixture#{System.unique_integer([:positive])}.MixProject"

    File.write!(Path.join(project_root, "mix.exs"), """
    defmodule #{module_name} do
      use Mix.Project
      def project, do: [app: :runner_fixture, version: "0.1.0", elixir: "~> 1.17", deps: deps()]
      def application, do: [extra_applications: [:logger]]
      defp deps, do: [{:mypkg, "~> 1.0"}]
    end
    """)

    File.write!(Path.join(project_root, "mix.lock"), """
    %{
      mypkg: {:hex, :mypkg, "1.0.0", "abc", [:mix], [], "hexpm", "def"}
    }
    """)
  end
end
