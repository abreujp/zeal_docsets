defmodule ZealDocsets.DocsetTest do
  use ExUnit.Case, async: true

  alias ZealDocsets.Dep
  alias ZealDocsets.Docset
  alias ZealDocsets.Fixtures
  alias ZealDocsets.Workspace

  describe "title_from_package/1" do
    test "capitalises a single-word package" do
      dep = %Dep{app: :phoenix, package: "phoenix"}
      assert Docset.title_from_package(dep) == "Phoenix"
    end

    test "capitalises and joins underscore-separated words" do
      dep = %Dep{app: :phoenix_live_view, package: "phoenix_live_view"}
      assert Docset.title_from_package(dep) == "Phoenix Live View"
    end
  end

  describe "default_install_root/0" do
    test "returns an absolute path" do
      assert Path.type(Docset.default_install_root()) == :absolute
    end
  end

  describe "build/3" do
    setup do
      {:ok, dep: %Dep{app: :mypkg, package: "mypkg", version: "1.0.0", source: :hex}}
    end

    test "generates the expected docset directory structure", %{dep: dep} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = setup_workspace(base)

        {:ok, docset_root, _installed} = Docset.build(dep, workspace, build_opts(dep))

        assert File.dir?(docset_root)
        assert File.exists?(Path.join(docset_root, "meta.json"))
        assert File.exists?(Path.join([docset_root, "Contents", "Info.plist"]))
        assert File.exists?(Path.join([docset_root, "Contents", "Resources", "docSet.dsidx"]))

        assert File.dir?(
                 Path.join([
                   docset_root,
                   "Contents",
                   "Resources",
                   "Documents",
                   "docs",
                   dep.package
                 ])
               )
      end)
    end

    test "returns skipped when version is already current", %{dep: dep} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = setup_workspace(base)

        assert {:ok, _path, _installed} = Docset.build(dep, workspace, build_opts(dep))
        assert {:skipped, _path} = Docset.build(dep, workspace, build_opts(dep))
      end)
    end

    test "rebuilds when force is true", %{dep: dep} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = setup_workspace(base)

        assert {:ok, _path, _installed} = Docset.build(dep, workspace, build_opts(dep))

        assert {:ok, _path, _installed} =
                 Docset.build(dep, workspace, build_opts(dep, force: true))
      end)
    end

    test "installs docset when install is true", %{dep: dep} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = setup_workspace(base)
        install_root = Path.join(base, "zeal_docsets")

        assert {:ok, _path, installed_path} =
                 Docset.build(
                   dep,
                   workspace,
                   build_opts(dep, install: true, install_root: install_root)
                 )

        assert installed_path == Path.join(install_root, "mypkg.docset")
        assert File.dir?(installed_path)
      end)
    end

    test "emits progress events while building", %{dep: dep} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = setup_workspace(base)
        test_pid = self()

        progress_fn = fn event -> send(test_pid, event) end

        assert {:ok, _path, _installed} =
                 Docset.build(dep, workspace, build_opts(dep, progress_fn: progress_fn))

        assert_received {:downloading, "mypkg", "1.0.0"}
        assert_received {:building, "mypkg", "1.0.0"}
        assert_received {:installing, "mypkg", "1.0.0", false}
        assert_received {:finished, "mypkg", "1.0.0"}
      end)
    end
  end

  defp setup_workspace(base) do
    workspace = Path.join(base, "workspace")
    Workspace.ensure!(workspace)
  end

  defp build_opts(dep, extra \\ []) do
    extra ++ [mirror_fn: fake_mirror(dep.package), install: false, warn_missing_icon: false]
  end

  defp fake_mirror(package) do
    fn _pkg, version, downloads_root ->
      mirror_root = Path.join([downloads_root, package, version])
      File.rm_rf!(mirror_root)
      File.mkdir_p!(mirror_root)
      Fixtures.write_docs_fixture(mirror_root, package)
      mirror_root
    end
  end
end
