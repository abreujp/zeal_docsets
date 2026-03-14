defmodule ZealDocsets.Docset do
  @moduledoc """
  Orchestrates the construction of a `.docset` bundle for a single dependency.

  A docset has the following on-disk layout:

      {package}.docset/
      ├── icon.png          ← package logo (if available)
      ├── icon@2x.png       ← same logo at 2× (for HiDPI displays)
      ├── meta.json         ← name, title, version metadata
      └── Contents/
          ├── Info.plist    ← Apple plist with Dash/Zeal configuration
          └── Resources/
              ├── docSet.dsidx              ← SQLite search index
              └── Documents/docs/{package}/ ← mirrored HTML documentation

  The build is skipped (and the existing docset optionally re-installed)
  when the current on-disk version matches the requested version, unless
  `force: true` is given.
  """

  alias ZealDocsets.Dep
  alias ZealDocsets.Hexdocs
  alias ZealDocsets.Index

  @doc """
  Builds a `.docset` bundle for `dep` inside `workspace_root/output/`.

  ## Options

  - `:force`        — when `true`, rebuilds even if the version is already
                      up to date. Defaults to `false`.
  - `:install`      — when `true`, copies the resulting docset to
                      `install_root`. Defaults to `true`.
  - `:install_root` — the Zeal docsets directory. Defaults to the
                      platform-specific Zeal docsets path.
  - `:mirror_fn`    — internal/testing hook that overrides the mirroring
                      function. Defaults to `&ZealDocsets.Hexdocs.mirror/3`.

  ## Return values

  - `{:ok, docset_path, installed_path}` — docset was (re)built and
    optionally installed. `installed_path` is `nil` when `install: false`.
  - `{:skipped, docset_path}` — existing docset is already at the correct
    version and was skipped.
  """
  @spec build(Dep.t(), Path.t(), keyword()) ::
          {:ok, Path.t(), Path.t() | nil} | {:skipped, Path.t()}
  def build(%Dep{} = dep, workspace_root, opts \\ []) do
    force? = Keyword.get(opts, :force, false)
    install? = Keyword.get(opts, :install, true)
    progress_fn = Keyword.get(opts, :progress_fn)
    install_root = Path.expand(Keyword.get(opts, :install_root, default_install_root()))
    output_root = Path.join(workspace_root, "output")
    display_title = title_from_package(dep)
    docset_root = Path.join(output_root, "#{dep.package}.docset")

    if not force? and current_version(docset_root) == dep.version do
      notify(progress_fn, {:skipped, dep.package, dep.version})
      maybe_install_existing(docset_root, install_root, install?)
      {:skipped, docset_root}
    else
      downloads_root = Path.join(workspace_root, "downloads")
      mirror_fn = Keyword.get(opts, :mirror_fn, &Hexdocs.mirror/3)

      notify(progress_fn, {:downloading, dep.package, dep.version})
      mirror_root = mirror_fn.(dep.package, dep.version, downloads_root)

      File.rm_rf!(docset_root)

      docs_root =
        Path.join([docset_root, "Contents", "Resources", "Documents", "docs", dep.package])

      notify(progress_fn, {:building, dep.package, dep.version})
      File.mkdir_p!(Path.dirname(docs_root))
      File.cp_r!(mirror_root, docs_root)
      write_info_plist!(docset_root, docs_root, dep, display_title)
      write_meta_json!(docset_root, dep, display_title)
      copy_icon(docset_root, docs_root)

      Index.build!(
        Path.join([docset_root, "Contents", "Resources", "docSet.dsidx"]),
        docs_root,
        dep.package
      )

      notify(progress_fn, {:installing, dep.package, dep.version, install?})
      installed_path = maybe_install_existing(docset_root, install_root, install?)
      notify(progress_fn, {:finished, dep.package, dep.version})
      {:ok, docset_root, installed_path}
    end
  end

  @doc """
  Returns the default Zeal docsets directory for the current platform.

  The default path is resolved for Linux, macOS, and Windows.
  """
  @spec default_install_root() :: Path.t()
  def default_install_root do
    case :os.type() do
      {:unix, :darwin} -> Path.expand("~/Library/Application Support/Zeal/Zeal/docsets")
      {:win32, _flavor} -> windows_zeal_path()
      _other -> Path.expand("~/.local/share/Zeal/Zeal/docsets")
    end
  end

  @doc """
  Derives a human-readable display title from a package name.

  Splits on underscores and capitalises each word:
  `"phoenix_live_view"` → `"Phoenix Live View"`.
  """
  @spec title_from_package(Dep.t()) :: String.t()
  def title_from_package(%Dep{package: package}) do
    package
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp current_version(docset_root) do
    meta_path = Path.join(docset_root, "meta.json")

    with true <- File.exists?(meta_path),
         {:ok, contents} <- File.read(meta_path),
         [_, version] <- Regex.run(~r/"version"\s*:\s*"([^"]+)"/, contents) do
      version
    else
      _other -> nil
    end
  end

  defp maybe_install_existing(docset_root, install_root, true) do
    File.mkdir_p!(install_root)
    destination = Path.join(install_root, Path.basename(docset_root))
    File.rm_rf!(destination)
    File.cp_r!(docset_root, destination)
    destination
  end

  defp maybe_install_existing(_docset_root, _install_root, false), do: nil

  defp write_info_plist!(docset_root, docs_root, dep, title) do
    index_file = index_file_path(docs_root, dep.package)

    info = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleIdentifier</key>
      <string>#{xml_escape(dep.package)}</string>
      <key>CFBundleName</key>
      <string>#{xml_escape(title)}</string>
      <key>DocSetPlatformFamily</key>
      <string>#{xml_escape(dep.package)}</string>
      <key>dashIndexFilePath</key>
      <string>#{xml_escape(index_file)}</string>
      <key>isDashDocset</key>
      <true/>
      <key>DashDocSetFamily</key>
      <string>unsorteddashtoc</string>
      <key>isJavaScriptEnabled</key>
      <true/>
      <key>DashDocSetDeclaredInStyle</key>
      <string>originalName</string>
      <key>DashDocSetPluginKeyword</key>
      <string>#{xml_escape(dep.package)}</string>
    </dict>
    </plist>
    """

    path = Path.join([docset_root, "Contents", "Info.plist"])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, info)
  end

  defp write_meta_json!(docset_root, dep, title) do
    contents = """
    {
      "name": "#{json_escape(title)}",
      "title": "#{json_escape(title)}",
      "version": "#{json_escape(dep.version)}",
      "extra": {
        "isJavaScriptEnabled": true
      }
    }
    """

    File.write!(Path.join(docset_root, "meta.json"), contents)
  end

  defp copy_icon(docset_root, docs_root) do
    logo_path = Path.join([docs_root, "assets", "logo.png"])

    if File.exists?(logo_path) do
      File.cp!(logo_path, Path.join(docset_root, "icon.png"))
      File.cp!(logo_path, Path.join(docset_root, "icon@2x.png"))
    end
  end

  defp windows_zeal_path do
    case System.get_env("APPDATA") do
      nil -> Path.expand("~/AppData/Roaming/Zeal/Zeal/docsets")
      appdata -> Path.join(appdata, "Zeal/Zeal/docsets")
    end
  end

  defp xml_escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp json_escape(value) do
    value
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\b", "\\b")
    |> String.replace("\f", "\\f")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
    |> String.replace("\t", "\\t")
  end

  defp index_file_path(docs_root, package) do
    relative_root = Path.join("docs", package)

    if File.exists?(Path.join(docs_root, "api-reference.html")) do
      Path.join(relative_root, "api-reference.html")
    else
      Path.join(relative_root, "index.html")
    end
  end

  defp notify(nil, _event), do: :ok
  defp notify(progress_fn, event), do: progress_fn.(event)
end
