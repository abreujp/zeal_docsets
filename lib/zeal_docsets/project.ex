defmodule ZealDocsets.Project do
  @moduledoc """
  Reads a Mix project's direct dependencies and their locked versions.

  Combines information from two sources:

  - **`mix.exs`** - identifies the direct dependencies of the project,
    their version requirements, and which Mix environments they belong to.
  - **`mix.lock`** - provides the exact resolved versions currently locked.

  Only Hex-sourced dependencies available in the `:prod` environment are
  included by default. Git and path dependencies are excluded because they may
  not have a corresponding page on hexdocs.pm. Extra packages requested via the
  CLI can also be appended even when they are not present in the target
  project's dependency tree.
  """

  alias ZealDocsets.Dep
  alias ZealDocsets.HexPackage
  alias ZealDocsets.HexPm

  @doc """
  Loads and returns the list of resolved direct Hex dependencies for the Mix
  project at `path`.

  ## Options

  - `:include_dev` - when `true`, also includes dependencies declared for the
    `:dev` environment. Defaults to `false`.
  - `:include_test` - when `true`, also includes dependencies declared for the
    `:test` environment. Defaults to `false`.
  - `:current_project` - when `true`, reads dependency information from the
    currently loaded Mix project instead of reloading the project from disk.
    This is the supported mode when `zeal_docsets` is used as a dependency.
  - `:extra_packages` - a list of extra Hex packages to include even when they
    are not declared in `mix.exs`. Each entry accepts `name` or `name@version`.

  ## Returns

  A list of `%ZealDocsets.Dep{}` structs sorted alphabetically by package name.
  Each struct has a confirmed `:hex` source and a non-nil `:version`.

  ## Raises

  - `ArgumentError` if `mix.exs` or `mix.lock` are not found at `path`.
  """
  @spec load!(Path.t(), keyword()) :: [Dep.t()]
  def load!(path, opts \\ []) do
    include_dev = Keyword.get(opts, :include_dev, false)
    include_test = Keyword.get(opts, :include_test, false)
    current_project = Keyword.get(opts, :current_project, false)
    progress_fn = Keyword.get(opts, :progress_fn)

    extra_packages =
      Keyword.get_values(opts, :extra_package) ++ Keyword.get(opts, :extra_packages, [])

    latest_version_fn = Keyword.get(opts, :latest_version_fn, &HexPm.latest_stable_version!/1)
    project_path = Path.expand(path)

    ensure_project_files!(project_path)

    deps =
      project_path
      |> direct_deps(current_project)
      |> Enum.map(&to_dep/1)
      |> Enum.filter(&keep_dep?(&1, include_dev, include_test))

    versions = lock_versions(project_path)
    extras = Enum.map(extra_packages, &extra_dep!(&1, latest_version_fn, progress_fn))

    deps
    |> Enum.map(&attach_version(&1, versions))
    |> Enum.filter(&(&1.source == :hex and is_binary(&1.version)))
    |> merge_extra_deps(extras)
    |> Enum.sort_by(& &1.package)
  end

  @doc """
  Parses an extra package specification.

  Accepted formats are `package` and `package@version`.
  """
  @spec parse_extra_package_spec!(String.t()) :: {String.t(), String.t() | nil}
  def parse_extra_package_spec!(spec) do
    spec = String.trim(spec)

    case String.split(spec, "@") do
      [package] -> {HexPackage.validate_name!(package), nil}
      [package, version] -> {HexPackage.validate_name!(package), validate_version!(version, spec)}
      _other -> raise ArgumentError, invalid_extra_package_message(spec)
    end
  end

  defp ensure_project_files!(project_path) do
    for file <- ["mix.exs", "mix.lock"] do
      full_path = Path.join(project_path, file)

      unless File.exists?(full_path) do
        raise ArgumentError, "file not found: #{full_path}"
      end
    end
  end

  defp direct_deps(_project_path, true) do
    Mix.Project.config()[:deps] || []
  end

  defp direct_deps(project_path, false) do
    project_name = temporary_project_name(project_path)

    Mix.Project.in_project(project_name, project_path, fn _module ->
      Mix.Project.config()[:deps] || []
    end)
  end

  defp temporary_project_name(project_path) do
    suffix = :erlang.phash2(project_path)
    String.to_atom("zeal_docsets_target_#{suffix}")
  end

  defp to_dep({app, requirement}) when is_atom(app) and is_binary(requirement) do
    %Dep{app: app, package: Atom.to_string(app), requirement: requirement, source: :hex}
  end

  defp to_dep({app, requirement, opts})
       when is_atom(app) and is_binary(requirement) and is_list(opts) do
    %Dep{
      app: app,
      package: Atom.to_string(app),
      requirement: requirement,
      source: dependency_source(opts),
      envs: dependency_envs(opts)
    }
  end

  defp to_dep({app, opts}) when is_atom(app) and is_list(opts) do
    %Dep{
      app: app,
      package: Atom.to_string(app),
      source: dependency_source(opts),
      envs: dependency_envs(opts)
    }
  end

  defp dependency_source(opts) do
    cond do
      Keyword.has_key?(opts, :git) -> :git
      Keyword.has_key?(opts, :path) -> :path
      Keyword.has_key?(opts, :hex) -> :hex
      true -> :hex
    end
  end

  defp dependency_envs(opts) do
    case Keyword.get(opts, :only) do
      nil -> [:prod]
      env when is_atom(env) -> [env]
      envs when is_list(envs) -> envs
    end
  end

  defp keep_dep?(%Dep{envs: envs}, include_dev, include_test) do
    selected_envs = selected_envs(include_dev, include_test)
    Enum.any?(envs, &(&1 in selected_envs))
  end

  defp selected_envs(include_dev, include_test) do
    [:prod]
    |> maybe_add_env(include_dev, :dev)
    |> maybe_add_env(include_test, :test)
  end

  defp maybe_add_env(envs, true, env), do: [env | envs]
  defp maybe_add_env(envs, false, _env), do: envs

  defp lock_versions(project_path) do
    lock_path = Path.join(project_path, "mix.lock")

    lock_data =
      lock_path
      |> File.read!()
      |> normalize_lock_keywords()
      |> Code.string_to_quoted!()
      |> Code.eval_quoted()
      |> elem(0)

    Enum.reduce(lock_data, %{}, fn {app, lock_value}, acc ->
      case lock_value do
        {:hex, package, version, _checksum, _managers, _deps, _repo, _outer_checksum} ->
          Map.put(acc, app, {to_string(package), version})

        {:hex, package, version, _checksum, _managers, _deps, _repo} ->
          Map.put(acc, app, {to_string(package), version})

        _other ->
          acc
      end
    end)
  end

  defp attach_version(%Dep{app: app} = dep, versions) do
    case Map.get(versions, app) do
      {package, version} -> %{dep | package: package, version: version, source: :hex}
      nil -> dep
    end
  end

  defp extra_dep!(spec, latest_version_fn, progress_fn) do
    {package, version} = parse_extra_package_spec!(spec)

    notify(progress_fn, {:resolving_extra_package, spec, package, version})

    resolved_version = version || latest_version_fn.(package)

    notify(progress_fn, {:resolved_extra_package, spec, package, resolved_version})

    %Dep{
      package: package,
      version: resolved_version,
      source: :hex
    }
  end

  defp merge_extra_deps(deps, []), do: deps

  defp merge_extra_deps(deps, extras) do
    deps
    |> Kernel.++(extras)
    |> Enum.reduce(%{}, fn dep, acc -> Map.put(acc, dep.package, dep) end)
    |> Map.values()
  end

  defp normalize_lock_keywords(contents) do
    Regex.replace(~r/"([A-Za-z0-9_]+)":/, contents, "\\1:")
  end

  defp validate_version!(version, spec) do
    version = String.trim(version)

    if version == "" do
      raise ArgumentError, invalid_extra_package_message(spec)
    else
      version
    end
  end

  defp invalid_extra_package_message(spec) do
    "invalid --extra-package value #{inspect(spec)}; expected package or package@version"
  end

  defp notify(nil, _event), do: :ok
  defp notify(progress_fn, event), do: progress_fn.(event)
end
