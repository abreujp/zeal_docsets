defmodule ZealDocsets.CLITest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias ZealDocsets.CLI

  describe "parse_args/1" do
    test "accepts one positional argument and uses default zeal path" do
      assert {:ok, project_path, zeal_path, []} = CLI.parse_args(["/tmp/my_app"])
      assert project_path == Path.expand("/tmp/my_app")
      assert zeal_path == CLI.default_zeal_path()
    end

    test "accepts two positional arguments" do
      assert {:ok, project_path, zeal_path, []} =
               CLI.parse_args(["/tmp/my_app", "/tmp/docsets"])

      assert project_path == Path.expand("/tmp/my_app")
      assert zeal_path == Path.expand("/tmp/docsets")
    end

    test "parses --dev and --concurrency flags" do
      assert {:ok, _proj, _zeal, opts} =
               CLI.parse_args(["/tmp/my_app", "/tmp/docsets", "--dev", "--concurrency", "4"])

      assert opts[:dev] == true
      assert opts[:concurrency] == 4
    end

    test "parses --force flag" do
      assert {:ok, _, _, opts} = CLI.parse_args(["/tmp/my_app", "--force"])
      assert opts[:force] == true
    end

    test "parses --test flag" do
      assert {:ok, _, _, opts} = CLI.parse_args(["/tmp/my_app", "--test"])
      assert opts[:test] == true
    end

    test "parses --no-install flag" do
      assert {:ok, _, _, opts} = CLI.parse_args(["/tmp/my_app", "--no-install"])
      assert opts[:no_install] == true
    end

    test "parses --package flag (single)" do
      assert {:ok, _, _, opts} = CLI.parse_args(["/tmp/my_app", "--package", "phoenix"])
      assert Keyword.get_values(opts, :package) == ["phoenix"]
    end

    test "parses --package flag (multiple)" do
      assert {:ok, _, _, opts} =
               CLI.parse_args(["/tmp/my_app", "--package", "phoenix", "--package", "ecto"])

      assert Keyword.get_values(opts, :package) == ["phoenix", "ecto"]
    end

    test "parses --extra-package flag (single and versioned)" do
      assert {:ok, _, _, opts} =
               CLI.parse_args(["/tmp/my_app", "--extra-package", "ecto@3.13.5"])

      assert Keyword.get_values(opts, :extra_package) == ["ecto@3.13.5"]
    end

    test "parses --extra-package flag (multiple)" do
      assert {:ok, _, _, opts} =
               CLI.parse_args([
                 "/tmp/my_app",
                 "--extra-package",
                 "ecto",
                 "--extra-package",
                 "plug@1.16.1"
               ])

      assert Keyword.get_values(opts, :extra_package) == ["ecto", "plug@1.16.1"]
    end

    test "parses --workspace flag" do
      assert {:ok, _, _, opts} = CLI.parse_args(["/tmp/my_app", "--workspace", "/tmp/ws"])
      assert opts[:workspace] == "/tmp/ws"
    end

    test "returns error for unknown option" do
      assert {:error, message} = CLI.parse_args(["/tmp/my_app", "--wat"])
      assert message =~ "unknown option"
    end

    test "returns error with no arguments" do
      assert {:error, message} = CLI.parse_args([])
      assert message =~ "positional argument"
    end
  end

  describe "exit_code/1" do
    test "returns 0 when no failures" do
      result = %{summary: %{failed: 0}}
      assert CLI.exit_code(result) == 0
    end

    test "returns 1 when there are failures" do
      result = %{summary: %{failed: 2}}
      assert CLI.exit_code(result) == 1
    end
  end

  describe "print_report/1" do
    test "prints header and 'no deps found' when results are empty" do
      result = %{
        project_path: "/proj",
        workspace: "/ws",
        zeal_path: "/zeal",
        install?: true,
        concurrency: 4,
        include_dev: false,
        include_test: false,
        extra_packages: [],
        missing_icons: [],
        results: [],
        summary: %{built: 0, skipped: 0, failed: 0}
      }

      output = capture_io(fn -> CLI.print_report(result) end)

      assert output =~ "Project:"
      assert output =~ "Extra pkgs:   none"
      assert output =~ "No matching Hex packages found."
    end

    test "prints summary when results are present" do
      result = %{
        project_path: "/proj",
        workspace: "/ws",
        zeal_path: "/zeal",
        install?: false,
        concurrency: 2,
        include_dev: true,
        include_test: false,
        extra_packages: ["ecto", "plug@1.16.1"],
        missing_icons: ["ecto", "phoenix"],
        results: [
          {:ok, "phoenix", "/some/path"},
          {:skipped, "ecto", "/other/path"}
        ],
        summary: %{built: 1, skipped: 1, failed: 0}
      }

      output = capture_io(fn -> CLI.print_report(result) end)

      assert output =~ "1 built"
      assert output =~ "1 skipped"
      assert output =~ "0 failed"
      assert output =~ "Include dev:  yes"
      assert output =~ "Install:      no"
      assert output =~ "Extra pkgs:   ecto, plug@1.16.1"
      assert output =~ "2 docsets were generated without a custom icon"
    end

    test "prints errors to stderr" do
      result = %{
        project_path: "/proj",
        workspace: "/ws",
        zeal_path: "/zeal",
        install?: true,
        concurrency: 1,
        include_dev: false,
        include_test: false,
        extra_packages: [],
        missing_icons: [],
        results: [
          {:error, "broken_pkg", "connection refused"}
        ],
        summary: %{built: 0, skipped: 0, failed: 1}
      }

      output =
        capture_io(:stderr, fn ->
          capture_io(fn -> CLI.print_report(result) end)
        end)

      assert output =~ "broken_pkg"
      assert output =~ "connection refused"
    end
  end

  describe "default_zeal_path/0" do
    test "returns an absolute path" do
      assert Path.type(CLI.default_zeal_path()) == :absolute
    end

    test "returns a Zeal-looking path" do
      path = CLI.default_zeal_path()
      assert String.contains?(path, "Zeal")
      assert String.ends_with?(path, "docsets")
    end
  end

  describe "run/3" do
    setup do
      project_root =
        Path.join(
          System.tmp_dir!(),
          "zeal_cli_fixture_#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(project_root)
      write_fixture_project(project_root)
      on_exit(fn -> File.rm_rf!(project_root) end)
      {:ok, project_root: project_root}
    end

    test "returns a run_result with the build summary and installs a default progress_fn",
         %{project_root: project_root} do
      ZealDocsets.Fixtures.with_tmp_dir(fn base ->
        workspace = Path.join(base, "workspace")
        zeal_path = Path.join(base, "zeal")

        output =
          capture_io(fn ->
            send(
              self(),
              CLI.run(project_root, zeal_path,
                workspace: workspace,
                no_install: true,
                current_project: false,
                warn_missing_icon: false,
                mirror_fn: fake_mirror()
              )
            )
          end)

        # CLI.run must wire up Runner.print_progress as the default progress_fn,
        # so "Starting" must appear on stdout even without an explicit progress_fn.
        assert output =~ "Starting mypkg"

        assert_received %{
          summary: %{built: 1, skipped: 0, failed: 0},
          results: [{:ok, "mypkg", _}]
        }
      end)
    end
  end

  defp write_fixture_project(project_root) do
    module_name = "CLIFixture#{System.unique_integer([:positive])}.MixProject"

    File.write!(Path.join(project_root, "mix.exs"), """
    defmodule #{module_name} do
      use Mix.Project
      def project, do: [app: :cli_fixture, version: "0.1.0", elixir: "~> 1.17", deps: deps()]
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

  defp fake_mirror do
    fn pkg, version, downloads_root ->
      mirror_root = Path.join([downloads_root, pkg, version])
      File.rm_rf!(mirror_root)
      File.mkdir_p!(mirror_root)
      ZealDocsets.Fixtures.write_docs_fixture(mirror_root, pkg)
      mirror_root
    end
  end
end
