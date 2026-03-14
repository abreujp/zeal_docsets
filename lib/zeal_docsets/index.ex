defmodule ZealDocsets.Index do
  @moduledoc """
  Builds the SQLite search index (`docSet.dsidx`) for a Zeal/Dash docset.

  The index is a SQLite database with a single `searchIndex` table:

      CREATE TABLE searchIndex(
        id   INTEGER PRIMARY KEY,
        name TEXT,
        type TEXT,
        path TEXT
      );

  Each row maps a named entry to a type and a relative HTML path (including
  anchor). Zeal uses this index to power its search bar.

  ## Entry types indexed

  - **Module** — one entry per module page (`main.page-module`).
  - **Command** — Mix tasks listed in `api-reference.html`.
  - **Function** — public functions in module summary sections.
  - **Type** — typespecs in module summary sections.
  - **Callback** — behaviour callbacks in module summary sections.
  - **Macro** — macros in module summary sections.
  - **Guide** — extra pages (`main.page-extra`), such as tutorials and guides.
  """

  alias Exqlite
  alias ZealDocsets.HTML

  @skip_html_files MapSet.new(["404.html", "api-reference.html", "index.html", "search.html"])
  @summary_type_map %{
    "summary-functions" => "Function",
    "summary-types" => "Type",
    "summary-callbacks" => "Callback",
    "summary-macros" => "Macro"
  }

  @doc """
  Builds the `docSet.dsidx` SQLite index at `db_path` from the mirrored
  documentation in `docs_root` for `package`.

  Removes any existing database at `db_path` before creating a fresh one.
  Raises on filesystem or SQLite errors.
  """
  @spec build!(Path.t(), Path.t(), String.t()) :: :ok
  def build!(db_path, docs_root, package) do
    File.rm_rf(db_path)
    File.mkdir_p!(Path.dirname(db_path))

    {:ok, conn} = Exqlite.start_link(database: db_path)

    Exqlite.query!(
      conn,
      "CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT)"
    )

    Exqlite.query!(conn, "CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path)")

    entries =
      package
      |> entries(docs_root)
      |> Enum.sort()

    Enum.each(entries, fn {name, type, path} ->
      Exqlite.query!(
        conn,
        "INSERT OR IGNORE INTO searchIndex(name, type, path) VALUES (?, ?, ?)",
        [name, type, path]
      )
    end)

    GenServer.stop(conn)
  end

  defp entries(package, docs_root) do
    docs_prefix = "docs/#{package}"

    api_entries =
      case Path.join(docs_root, "api-reference.html") do
        api_reference_path ->
          if File.exists?(api_reference_path) do
            api_reference_path
            |> File.read!()
            |> Floki.parse_document!()
            |> api_entries(docs_prefix)
          else
            []
          end
      end

    page_entries =
      docs_root
      |> Path.join("*.html")
      |> Path.wildcard()
      |> Enum.reject(&MapSet.member?(@skip_html_files, Path.basename(&1)))
      |> Enum.flat_map(&page_entries(&1, docs_prefix))

    MapSet.new(api_entries ++ page_entries) |> MapSet.to_list()
  end

  defp api_entries(document, docs_prefix) do
    module_entries = collect_api_section(document, "modules", "Module", docs_prefix)
    task_entries = collect_api_section(document, "tasks", "Command", docs_prefix)
    module_entries ++ task_entries
  end

  defp collect_api_section(document, id, type, docs_prefix) do
    Floki.find(document, "h2##{id} + .summary .summary-signature a")
    |> Enum.map(fn node ->
      {HTML.text([node]), type, Path.join(docs_prefix, HTML.attr(node, "href"))}
    end)
    |> Enum.reject(fn {name, _type, path} -> is_nil(name) or is_nil(path) end)
  end

  defp page_entries(html_path, docs_prefix) do
    document = html_path |> File.read!() |> Floki.parse_document!()
    relative_path = Path.join(docs_prefix, Path.basename(html_path))

    cond do
      Floki.find(document, "main.page-module") != [] ->
        module_page_entries(document, relative_path, html_path)

      Floki.find(document, "main.page-extra") != [] ->
        guide_page_entries(document, relative_path)

      true ->
        []
    end
  end

  defp module_page_entries(document, relative_path, html_path) do
    module_name =
      Floki.find(document, "main.page-module h1 span[translate=no]")
      |> HTML.text()
      |> Kernel.||(Path.rootname(Path.basename(html_path)))

    summary_entries =
      Enum.flat_map(@summary_type_map, fn {class_name, type} ->
        Floki.find(document, ".#{class_name} .summary-signature a")
        |> Enum.map(fn node ->
          {HTML.text([node]), type, relative_path <> (HTML.attr(node, "href") || "")}
        end)
      end)

    [{module_name, "Module", relative_path} | summary_entries]
    |> Enum.reject(fn {name, _type, path} -> is_nil(name) or is_nil(path) end)
  end

  defp guide_page_entries(document, relative_path) do
    case Floki.find(document, "title") |> HTML.text() do
      nil -> []
      title -> [{title |> String.split(" — ") |> List.first(), "Guide", relative_path}]
    end
  end
end
