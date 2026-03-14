defmodule ZealDocsets.IndexTest do
  use ExUnit.Case, async: true

  alias ZealDocsets.Fixtures
  alias ZealDocsets.Index

  describe "build!/3" do
    test "creates the SQLite database file" do
      Fixtures.with_tmp_dir(fn base ->
        docs_root = Fixtures.write_docs_fixture(Path.join(base, "docs"))
        db_path = Path.join(base, "docSet.dsidx")

        Index.build!(db_path, docs_root, "mypkg")

        assert File.exists?(db_path)
      end)
    end

    test "indexes Module entries from module pages" do
      Fixtures.with_tmp_dir(fn base ->
        docs_root = Fixtures.write_docs_fixture(Path.join(base, "docs"))
        db_path = Path.join(base, "docSet.dsidx")

        Index.build!(db_path, docs_root, "mypkg")

        rows = Fixtures.read_index(db_path)
        assert {"MyModule", "Module", "docs/mypkg/my_module.html"} in rows
      end)
    end

    test "indexes Function entries from module summary" do
      Fixtures.with_tmp_dir(fn base ->
        docs_root = Fixtures.write_docs_fixture(Path.join(base, "docs"))
        db_path = Path.join(base, "docSet.dsidx")

        Index.build!(db_path, docs_root, "mypkg")

        rows = Fixtures.read_index(db_path)
        assert {"hello/1", "Function", "docs/mypkg/my_module.html#hello/1"} in rows
        assert {"world/0", "Function", "docs/mypkg/my_module.html#world/0"} in rows
      end)
    end

    test "indexes Type entries" do
      Fixtures.with_tmp_dir(fn base ->
        docs_root = Fixtures.write_docs_fixture(Path.join(base, "docs"))
        db_path = Path.join(base, "docSet.dsidx")

        Index.build!(db_path, docs_root, "mypkg")

        rows = Fixtures.read_index(db_path)
        assert {"my_type/0", "Type", "docs/mypkg/my_module.html#t:my_type/0"} in rows
      end)
    end

    test "indexes Callback entries" do
      Fixtures.with_tmp_dir(fn base ->
        docs_root = Fixtures.write_docs_fixture(Path.join(base, "docs"))
        db_path = Path.join(base, "docSet.dsidx")

        Index.build!(db_path, docs_root, "mypkg")

        rows = Fixtures.read_index(db_path)
        assert {"on_event/1", "Callback", "docs/mypkg/my_module.html#c:on_event/1"} in rows
      end)
    end

    test "indexes Macro entries" do
      Fixtures.with_tmp_dir(fn base ->
        docs_root = Fixtures.write_docs_fixture(Path.join(base, "docs"))
        db_path = Path.join(base, "docSet.dsidx")

        Index.build!(db_path, docs_root, "mypkg")

        rows = Fixtures.read_index(db_path)
        assert {"my_macro/1", "Macro", "docs/mypkg/my_module.html#my_macro/1"} in rows
      end)
    end

    test "indexes Guide entries from extra pages" do
      Fixtures.with_tmp_dir(fn base ->
        docs_root = Fixtures.write_docs_fixture(Path.join(base, "docs"))
        db_path = Path.join(base, "docSet.dsidx")

        Index.build!(db_path, docs_root, "mypkg")

        rows = Fixtures.read_index(db_path)
        assert {"Getting Started", "Guide", "docs/mypkg/getting-started.html"} in rows
      end)
    end

    test "indexes Module and Command entries from api-reference.html" do
      Fixtures.with_tmp_dir(fn base ->
        docs_root = Fixtures.write_docs_fixture(Path.join(base, "docs"))
        db_path = Path.join(base, "docSet.dsidx")

        Index.build!(db_path, docs_root, "mypkg")

        rows = Fixtures.read_index(db_path)
        assert {"MyModule", "Module", "docs/mypkg/my_module.html"} in rows
        assert {"mix.my_task", "Command", "docs/mypkg/mix.my_task.html"} in rows
      end)
    end

    test "does not index skipped files (index.html, search.html, 404.html)" do
      Fixtures.with_tmp_dir(fn base ->
        docs_root = Fixtures.write_docs_fixture(Path.join(base, "docs"))

        # Write files that should be skipped
        Enum.each(["index.html", "search.html", "404.html"], fn name ->
          File.write!(Path.join(docs_root, name), Fixtures.module_html())
        end)

        db_path = Path.join(base, "docSet.dsidx")
        Index.build!(db_path, docs_root, "mypkg")

        rows = Fixtures.read_index(db_path)
        paths = Enum.map(rows, &elem(&1, 2))

        refute "docs/mypkg/index.html" in paths
        refute "docs/mypkg/search.html" in paths
        refute "docs/mypkg/404.html" in paths
      end)
    end

    test "overwrites an existing database" do
      Fixtures.with_tmp_dir(fn base ->
        docs_root = Fixtures.write_docs_fixture(Path.join(base, "docs"))
        db_path = Path.join(base, "docSet.dsidx")

        Index.build!(db_path, docs_root, "mypkg")
        first_size = File.stat!(db_path).size

        Index.build!(db_path, docs_root, "mypkg")
        second_size = File.stat!(db_path).size

        assert first_size == second_size
      end)
    end

    test "works when api-reference.html is absent" do
      Fixtures.with_tmp_dir(fn base ->
        docs_root = Path.join(base, "docs")
        File.mkdir_p!(docs_root)
        File.write!(Path.join(docs_root, "my_module.html"), Fixtures.module_html())

        db_path = Path.join(base, "docSet.dsidx")
        Index.build!(db_path, docs_root, "mypkg")

        rows = Fixtures.read_index(db_path)
        assert {"MyModule", "Module", "docs/mypkg/my_module.html"} in rows
      end)
    end
  end
end
