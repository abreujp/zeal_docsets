defmodule ZealDocsets.Fixtures do
  @moduledoc false

  @doc """
  Creates a minimal but realistic hexdocs-like directory structure under `root`.

  Writes:
  - `api-reference.html`  — lists one module and one Mix task
  - `my_module.html`      — a module page with functions, types, callbacks, macros
  - `getting-started.html` — a guide page (page-extra)

  Returns the `root` path.
  """
  def write_docs_fixture(root, package \\ "mypkg") do
    File.mkdir_p!(root)

    File.write!(Path.join(root, "api-reference.html"), api_reference_html(package))
    File.write!(Path.join(root, "my_module.html"), module_html())
    File.write!(Path.join(root, "getting-started.html"), guide_html())

    root
  end

  def api_reference_html(package) do
    """
    <!DOCTYPE html>
    <html>
    <head><title>API Reference — #{package}</title></head>
    <body>
      <h2 id="modules">Modules</h2>
      <div class="summary">
        <div class="summary-signature">
          <a href="my_module.html">MyModule</a>
        </div>
      </div>
      <h2 id="tasks">Mix Tasks</h2>
      <div class="summary">
        <div class="summary-signature">
          <a href="mix.my_task.html">mix.my_task</a>
        </div>
      </div>
    </body>
    </html>
    """
  end

  def module_html do
    """
    <!DOCTYPE html>
    <html>
    <head><title>MyModule — mypkg v1.0.0</title></head>
    <body>
      <main class="page-module">
        <h1><span translate="no">MyModule</span></h1>

        <div class="summary-functions">
          <div class="summary-signature">
            <a href="#hello/1">hello/1</a>
          </div>
          <div class="summary-signature">
            <a href="#world/0">world/0</a>
          </div>
        </div>

        <div class="summary-types">
          <div class="summary-signature">
            <a href="#t:my_type/0">my_type/0</a>
          </div>
        </div>

        <div class="summary-callbacks">
          <div class="summary-signature">
            <a href="#c:on_event/1">on_event/1</a>
          </div>
        </div>

        <div class="summary-macros">
          <div class="summary-signature">
            <a href="#my_macro/1">my_macro/1</a>
          </div>
        </div>
      </main>
    </body>
    </html>
    """
  end

  def guide_html do
    """
    <!DOCTYPE html>
    <html>
    <head><title>Getting Started — mypkg v1.0.0</title></head>
    <body>
      <main class="page-extra">
        <h1>Getting Started</h1>
        <p>Welcome to mypkg!</p>
      </main>
    </body>
    </html>
    """
  end

  @doc """
  Creates a temp directory, yields it to `fun`, and cleans it up afterwards.
  """
  def with_tmp_dir(fun) do
    dir = Path.join(System.tmp_dir!(), "zeal_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    try do
      fun.(dir)
    after
      File.rm_rf!(dir)
    end
  end

  @doc """
  Queries all rows from a `docSet.dsidx` SQLite file.
  Returns a list of `{name, type, path}` tuples sorted for determinism.
  """
  def read_index(db_path) do
    {:ok, conn} = Exqlite.start_link(database: db_path)

    %{rows: rows} =
      Exqlite.query!(conn, "SELECT name, type, path FROM searchIndex ORDER BY name, type, path")

    GenServer.stop(conn)
    Enum.map(rows, fn [name, type, path] -> {name, type, path} end)
  end
end
