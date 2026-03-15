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

    test "handles package names with hyphens (treated as single word)" do
      dep = %Dep{app: :my_pkg, package: "my-pkg"}
      assert Docset.title_from_package(dep) == "My-pkg"
    end
  end

  describe "default_install_root/0" do
    test "returns an absolute path" do
      assert Path.type(Docset.default_install_root()) == :absolute
    end

    test "returns a path containing 'Zeal'" do
      assert Docset.default_install_root() =~ "Zeal"
    end

    test "returns a path ending with 'docsets'" do
      assert String.ends_with?(Docset.default_install_root(), "docsets")
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

    test "copies icon files when logo.png is present in mirrored docs", %{dep: dep} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = setup_workspace(base)

        {:ok, docset_root, _installed} =
          Docset.build(
            dep,
            workspace,
            build_opts(dep, mirror_fn: fake_mirror_with_logo(dep.package))
          )

        assert File.exists?(Path.join(docset_root, "icon.png"))
        assert File.exists?(Path.join(docset_root, "icon@2x.png"))
      end)
    end

    test "uses index.html as dashIndexFilePath when api-reference.html is absent", %{dep: dep} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = setup_workspace(base)

        {:ok, docset_root, _installed} =
          Docset.build(
            dep,
            workspace,
            build_opts(dep, mirror_fn: fake_mirror_without_api_reference(dep.package))
          )

        plist = File.read!(Path.join([docset_root, "Contents", "Info.plist"]))
        assert plist =~ "docs/mypkg/index.html"
        refute plist =~ "api-reference.html"
      end)
    end

    test "meta.json contains correct version and title", %{dep: dep} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = setup_workspace(base)

        {:ok, docset_root, _installed} = Docset.build(dep, workspace, build_opts(dep))

        meta = File.read!(Path.join(docset_root, "meta.json"))
        assert meta =~ ~s("version": "1.0.0")
        assert meta =~ ~s("title": "Mypkg")
      end)
    end

    test "Info.plist XML-escapes special characters in package identifier", %{dep: _dep} do
      # The package name goes directly into xml_escape for CFBundleIdentifier and
      # CFBundleName. A name with "&" and "<" would produce invalid XML if not escaped.
      dep = %Dep{app: :test, package: "my&pkg<v2>", version: "1.0.0", source: :hex}

      Fixtures.with_tmp_dir(fn base ->
        workspace = setup_workspace(base)

        {:ok, docset_root, _installed} =
          Docset.build(dep, workspace, build_opts(dep, mirror_fn: fake_mirror_for("my&pkg<v2>")))

        plist = File.read!(Path.join([docset_root, "Contents", "Info.plist"]))
        # The & must be escaped as &amp; and < as &lt;
        assert plist =~ "my&amp;pkg&lt;v2&gt;"
        # No bare & or < in string values
        refute plist =~ ~r/<string>[^<]*&(?!amp;|lt;|gt;|quot;|apos;)[^<]*<\/string>/
      end)
    end

    test "meta.json JSON-escapes special characters in title", %{dep: _dep} do
      # Simulate a package whose title would contain JSON-special chars if not escaped
      dep = %Dep{app: :my_pkg, package: "my_pkg", version: ~s(1.0.0"evil), source: :hex}

      Fixtures.with_tmp_dir(fn base ->
        workspace = setup_workspace(base)

        {:ok, docset_root, _installed} = Docset.build(dep, workspace, build_opts(dep))

        meta = File.read!(Path.join(docset_root, "meta.json"))
        # The version string with a quote must be escaped as \"
        assert meta =~ ~s("version": "1.0.0\\"evil")
        # The raw unescaped quote must not break the JSON structure
        refute meta =~ ~s("version": "1.0.0"evil)
      end)
    end

    test "emits skipped progress event when version is already current", %{dep: dep} do
      Fixtures.with_tmp_dir(fn base ->
        workspace = setup_workspace(base)
        test_pid = self()
        progress_fn = fn event -> send(test_pid, event) end

        Docset.build(dep, workspace, build_opts(dep))

        Docset.build(dep, workspace, build_opts(dep, progress_fn: progress_fn))

        assert_received {:skipped, "mypkg", "1.0.0"}
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

  # Like fake_mirror but uses a safe filesystem name derived from the package
  # (so paths with special characters like & or < don't break File.mkdir_p!)
  defp fake_mirror_for(package) do
    safe_name = String.replace(package, ~r/[^a-z0-9_]/, "_")

    fn _pkg, version, downloads_root ->
      mirror_root = Path.join([downloads_root, safe_name, version])
      File.rm_rf!(mirror_root)
      File.mkdir_p!(mirror_root)
      Fixtures.write_docs_fixture(mirror_root, safe_name)
      mirror_root
    end
  end

  defp fake_mirror_with_logo(package) do
    fn _pkg, version, downloads_root ->
      mirror_root = Path.join([downloads_root, package, version])
      File.rm_rf!(mirror_root)
      File.mkdir_p!(mirror_root)
      Fixtures.write_docs_fixture(mirror_root, package)
      assets_dir = Path.join(mirror_root, "assets")
      File.mkdir_p!(assets_dir)
      # Write a minimal valid 1x1 PNG as the logo
      File.write!(Path.join(assets_dir, "logo.png"), png_1x1())
      mirror_root
    end
  end

  defp fake_mirror_without_api_reference(package) do
    fn _pkg, version, downloads_root ->
      mirror_root = Path.join([downloads_root, package, version])
      File.rm_rf!(mirror_root)
      File.mkdir_p!(mirror_root)
      File.write!(Path.join(mirror_root, "my_module.html"), Fixtures.module_html())
      File.write!(Path.join(mirror_root, "index.html"), Fixtures.guide_html())
      _ = package
      mirror_root
    end
  end

  # Minimal valid 1×1 transparent PNG (67 bytes)
  defp png_1x1 do
    <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 2,
      0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84, 8, 215, 99, 248, 15, 0, 0, 1, 1, 0,
      5, 24, 213, 78, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130>>
  end
end
