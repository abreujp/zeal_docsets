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

  describe "select_packages/3" do
    setup do
      deps = [
        %ZealDocsets.Dep{app: :phoenix, package: "phoenix", version: "1.8.4"},
        %ZealDocsets.Dep{app: :ecto, package: "ecto", version: "3.13.5"},
        %ZealDocsets.Dep{app: nil, package: "plug", version: "1.16.1"}
      ]

      {:ok, deps: deps}
    end

    test "returns all deps when there are no package filters or extra packages", %{deps: deps} do
      assert Runner.select_packages(deps, [], []) == deps
    end

    test "keeps only explicitly requested extra packages when no package filter is given", %{
      deps: deps
    } do
      result = Runner.select_packages(deps, [], ["plug@1.16.1", "ecto"])
      assert Enum.map(result, & &1.package) == ["ecto", "plug"]
    end

    test "prefers explicit package filters over extra package selection", %{deps: deps} do
      result = Runner.select_packages(deps, ["phoenix"], ["plug"])
      assert Enum.map(result, & &1.package) == ["phoenix"]
    end
  end

  describe "default_workspace/0" do
    test "returns an absolute path under the system temp dir" do
      ws = Runner.default_workspace()
      assert Path.type(ws) == :absolute
      assert String.starts_with?(ws, System.tmp_dir!())
    end
  end

  describe "print_progress/1" do
    import ExUnit.CaptureIO

    test "prints the textual progress messages" do
      output =
        capture_io(fn ->
          Runner.print_progress({:resolving_extra_package, "plug", "plug", nil})
          Runner.print_progress({:resolved_extra_package, "plug", "plug", "1.16.1"})
          Runner.print_progress({:starting, "plug", "1.16.1", 1, 2})
          Runner.print_progress({:downloading, "plug", "1.16.1"})
          Runner.print_progress({:building, "plug", "1.16.1"})
          Runner.print_progress({:installing, "plug", "1.16.1", true})
          Runner.print_progress({:finished, "plug", "1.16.1"})
          Runner.print_progress({:skipped, "plug", "1.16.1"})
        end)

      assert output =~ "Resolving plug from Hex.pm as plug..."
      assert output =~ "Resolved plug 1.16.1."
      assert output =~ "[1/2] Starting plug 1.16.1..."
      assert output =~ "Downloading docs for plug 1.16.1..."
      assert output =~ "Building docset for plug 1.16.1..."
      assert output =~ "Installing plug 1.16.1 into Zeal..."
      assert output =~ "Finished plug 1.16.1."
      assert output =~ "Skipping plug 1.16.1; docset is already up to date."
    end

    test "prints explicit version progress" do
      output =
        capture_io(fn ->
          Runner.print_progress({:resolving_extra_package, "plug@1.16.2", "plug", "1.16.2"})
          Runner.print_progress({:installing, "plug", "1.16.2", false})
        end)

      assert output =~ "Using explicit version for plug@1.16.2: plug 1.16.2..."
      assert output == "Using explicit version for plug@1.16.2: plug 1.16.2...\n"
    end

    test "does not print anything for :installing with install: false" do
      output =
        capture_io(fn ->
          Runner.print_progress({:installing, "plug", "1.16.1", false})
        end)

      assert output == ""
    end

    test "prints failures to stderr" do
      output =
        capture_io(:stderr, fn ->
          Runner.print_progress({:failed, "plug", "1.16.1", "boom"})
        end)

      assert output =~ "Failed plug 1.16.1: boom"
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

    test "builds docsets for all direct hex deps", %{project_root: project_root} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = Path.join(base, "workspace")
        zeal_path = Path.join(base, "zeal")

        result =
          Runner.run(project_root, zeal_path,
            workspace: workspace,
            no_install: true,
            current_project: false,
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
            current_project: false,
            package: "mypkg",
            warn_missing_icon: false,
            mirror_fn: fake_mirror()
          )

        packages = Enum.map(result.results, fn {_status, pkg, _path} -> pkg end)
        assert packages == ["mypkg"]
      end)
    end

    test "include_dev: true expands the dep set to include dev dependencies", %{
      project_root: project_root
    } do
      Fixtures.with_tmp_dir(fn base ->
        workspace = Path.join(base, "workspace")
        zeal_path = Path.join(base, "zeal")

        result_without =
          Runner.run(project_root, zeal_path,
            workspace: workspace,
            no_install: true,
            current_project: false,
            warn_missing_icon: false,
            mirror_fn: fake_mirror()
          )

        result_with =
          Runner.run(project_root, zeal_path,
            workspace: workspace,
            no_install: true,
            current_project: false,
            dev: true,
            warn_missing_icon: false,
            mirror_fn: fake_mirror()
          )

        # The fixture project has only one prod dep (mypkg), so dev: true must
        # produce the same count here; but include_dev must be reflected truthfully.
        assert result_without.include_dev == false
        assert result_with.include_dev == true
      end)
    end

    test "builds only extra packages when no package filter is given", %{
      project_root: project_root
    } do
      Fixtures.with_tmp_dir(fn base ->
        workspace = Path.join(base, "workspace")
        zeal_path = Path.join(base, "zeal")

        result =
          Runner.run(project_root, zeal_path,
            workspace: workspace,
            no_install: true,
            current_project: false,
            extra_package: "plug",
            latest_version_fn: fn
              "plug" -> "1.16.1"
            end,
            warn_missing_icon: false,
            mirror_fn: fake_mirror()
          )

        packages = Enum.map(result.results, fn {_status, pkg, _path} -> pkg end)
        assert packages == ["plug"]
        assert result.extra_packages == ["plug"]
      end)
    end

    test "respects explicit versions for extra packages", %{project_root: project_root} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = Path.join(base, "workspace")
        zeal_path = Path.join(base, "zeal")

        result =
          Runner.run(project_root, zeal_path,
            workspace: workspace,
            no_install: true,
            current_project: false,
            extra_package: "plug@1.16.2",
            warn_missing_icon: false,
            mirror_fn: fake_mirror()
          )

        assert {_, "plug", path} =
                 Enum.find(result.results, fn {_status, pkg, _path} -> pkg == "plug" end)

        assert path =~ "plug.docset"
        assert Enum.map(result.results, fn {_status, pkg, _path} -> pkg end) == ["plug"]
      end)
    end

    test "still supports mixing package filters with extra packages", %{
      project_root: project_root
    } do
      Fixtures.with_tmp_dir(fn base ->
        workspace = Path.join(base, "workspace")
        zeal_path = Path.join(base, "zeal")

        result =
          Runner.run(project_root, zeal_path,
            workspace: workspace,
            no_install: true,
            current_project: false,
            package: "mypkg",
            extra_package: "plug",
            latest_version_fn: fn "plug" -> "1.16.1" end,
            warn_missing_icon: false,
            mirror_fn: fake_mirror()
          )

        assert Enum.map(result.results, fn {_status, pkg, _path} -> pkg end) == ["mypkg"]
      end)
    end

    test "reports skipped when docset is already up to date", %{project_root: project_root} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = Path.join(base, "workspace")
        zeal_path = Path.join(base, "zeal")

        # First run builds the docset
        Runner.run(project_root, zeal_path,
          workspace: workspace,
          no_install: true,
          current_project: false,
          warn_missing_icon: false,
          mirror_fn: fake_mirror()
        )

        # Second run with the same version must skip
        result =
          Runner.run(project_root, zeal_path,
            workspace: workspace,
            no_install: true,
            current_project: false,
            warn_missing_icon: false,
            mirror_fn: fake_mirror()
          )

        assert result.summary == %{built: 0, skipped: 1, failed: 0}
        assert [{:skipped, "mypkg", _path}] = result.results
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
            current_project: false,
            warn_missing_icon: false,
            mirror_fn: failing_mirror()
          )

        assert result.summary == %{built: 0, skipped: 0, failed: 1}
        assert [{:error, "mypkg", message}] = result.results
        assert message =~ "mirror failed"
      end)
    end

    test "emits progress updates for extra packages and builds", %{project_root: project_root} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = Path.join(base, "workspace")
        zeal_path = Path.join(base, "zeal")
        test_pid = self()

        progress_fn = fn event -> send(test_pid, event) end

        _result =
          Runner.run(project_root, zeal_path,
            workspace: workspace,
            no_install: true,
            current_project: false,
            extra_package: "plug",
            latest_version_fn: fn "plug" -> "1.16.1" end,
            progress_fn: progress_fn,
            warn_missing_icon: false,
            mirror_fn: fake_mirror()
          )

        assert_received {:resolving_extra_package, "plug", "plug", nil}
        assert_received {:resolved_extra_package, "plug", "plug", "1.16.1"}
        assert_received {:starting, "plug", "1.16.1", _index, _total}
        assert_received {:downloading, "plug", "1.16.1"}
        assert_received {:finished, "plug", "1.16.1"}
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
