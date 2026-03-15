defmodule ZealDocsets.WorkspaceTest do
  use ExUnit.Case, async: true

  alias ZealDocsets.Fixtures
  alias ZealDocsets.Workspace

  describe "ensure!/1" do
    test "creates the root and required subdirectories" do
      Fixtures.with_tmp_dir(fn base ->
        root = Path.join(base, "workspace")

        result = Workspace.ensure!(root)

        assert result == root
        assert File.dir?(root)
        assert File.dir?(Path.join(root, "downloads"))
        assert File.dir?(Path.join(root, "output"))
      end)
    end

    test "is idempotent — does not fail if directories already exist" do
      Fixtures.with_tmp_dir(fn base ->
        root = Path.join(base, "workspace")
        Workspace.ensure!(root)

        assert Workspace.ensure!(root) == root
      end)
    end

    test "expands relative paths to absolute" do
      # Change to a known directory so a relative path is predictable
      original_cwd = File.cwd!()

      Fixtures.with_tmp_dir(fn base ->
        File.cd!(base)

        relative = "zeal_ws_relative_#{System.unique_integer([:positive])}"
        result = Workspace.ensure!(relative)

        assert Path.type(result) == :absolute
        assert result == Path.join(base, relative)
        File.rm_rf!(result)
        File.cd!(original_cwd)
      end)
    end
  end
end
