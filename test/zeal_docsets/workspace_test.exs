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
      Fixtures.with_tmp_dir(fn _base ->
        result =
          Workspace.ensure!(
            System.tmp_dir!() <> "/zeal_ws_test_#{System.unique_integer([:positive])}"
          )

        assert Path.type(result) == :absolute
        File.rm_rf!(result)
      end)
    end
  end
end
