defmodule ZealDocsets.Runner do
  @moduledoc """
  Coordinates dependency selection and docset generation for a target project.

  This module contains the side-effectful build pipeline but does not exit the
  VM. It returns a structured result that can be rendered by the CLI, Mix task,
  or tests.
  """

  alias ZealDocsets.Docset
  alias ZealDocsets.Project
  alias ZealDocsets.Workspace

  @type progress_event ::
          {:resolving_extra_package, String.t(), String.t(), String.t() | nil}
          | {:resolved_extra_package, String.t(), String.t(), String.t()}
          | {:starting, String.t(), String.t(), pos_integer(), non_neg_integer()}
          | {:downloading, String.t(), String.t()}
          | {:building, String.t(), String.t()}
          | {:installing, String.t(), String.t(), boolean()}
          | {:finished, String.t(), String.t()}
          | {:skipped, String.t(), String.t()}
          | {:failed, String.t(), String.t(), String.t()}

  @type result :: {:ok | :skipped | :error, String.t(), String.t()}

  @type summary :: %{
          built: non_neg_integer(),
          skipped: non_neg_integer(),
          failed: non_neg_integer()
        }

  @type run_result :: %{
          project_path: Path.t(),
          workspace: Path.t(),
          zeal_path: Path.t(),
          install?: boolean(),
          concurrency: pos_integer(),
          include_dev: boolean(),
          include_test: boolean(),
          extra_packages: [String.t()],
          missing_icons: [String.t()],
          results: [result()],
          summary: summary()
        }

  @doc """
  Runs dependency discovery and docset generation for a target project.

  Returns a map containing execution settings, per-package results, a build
  summary, and a list of packages whose generated docsets do not include a
  custom icon.
  """
  @spec run(Path.t(), Path.t(), keyword()) :: run_result()
  def run(project_path, zeal_path, opts) do
    workspace =
      opts
      |> Keyword.get(:workspace, default_workspace())
      |> Workspace.ensure!()

    install? = not Keyword.get(opts, :no_install, false)
    concurrency = max(1, Keyword.get(opts, :concurrency, System.schedulers_online()))
    include_dev = Keyword.get(opts, :dev, false) or Keyword.get(opts, :include_dev, false)
    include_test = Keyword.get(opts, :test, false) or Keyword.get(opts, :include_test, false)
    extra_packages = Keyword.get_values(opts, :extra_package)
    progress_fn = Keyword.get(opts, :progress_fn)

    project_opts =
      [
        include_dev: include_dev,
        include_test: include_test,
        current_project: Keyword.get(opts, :current_project, false),
        extra_packages: extra_packages,
        progress_fn: progress_fn
      ]
      |> maybe_put(:latest_version_fn, Keyword.get(opts, :latest_version_fn))

    deps =
      project_path
      |> Project.load!(project_opts)
      |> filter_packages(Keyword.get_values(opts, :package))

    total = length(deps)

    results =
      deps
      |> Enum.with_index(1)
      |> Task.async_stream(
        fn {dep, index} ->
          label = "[#{index}/#{total}] #{dep.package} #{dep.version}"

          try do
            notify(progress_fn, {:starting, dep.package, dep.version, index, total})

            build_opts =
              [
                force: Keyword.get(opts, :force, false),
                install: install?,
                install_root: zeal_path,
                warn_missing_icon: Keyword.get(opts, :warn_missing_icon, true),
                progress_fn: progress_fn
              ]
              |> maybe_put(:mirror_fn, Keyword.get(opts, :mirror_fn))

            case Docset.build(dep, workspace, build_opts) do
              {:ok, docset_path, _installed_path} ->
                {:ok, dep.package, docset_path, label}

              {:skipped, docset_path} ->
                {:skipped, dep.package, docset_path, label}
            end
          rescue
            error ->
              notify(progress_fn, {:failed, dep.package, dep.version, Exception.message(error)})
              {:error, dep.package, Exception.message(error), label}
          end
        end,
        max_concurrency: concurrency,
        ordered: false,
        timeout: :infinity
      )
      |> Enum.map(fn
        {:ok, {:ok, package, path, _label}} -> {:ok, package, path}
        {:ok, {:skipped, package, path, _label}} -> {:skipped, package, path}
        {:ok, {:error, package, message, _label}} -> {:error, package, message}
        {:exit, reason} -> {:error, "unknown", Exception.format_exit(reason)}
      end)

    missing_icons = collect_missing_icons(results)

    %{
      project_path: Path.expand(project_path),
      workspace: workspace,
      zeal_path: Path.expand(zeal_path),
      install?: install?,
      concurrency: concurrency,
      include_dev: include_dev,
      include_test: include_test,
      extra_packages: extra_packages,
      missing_icons: missing_icons,
      results: results,
      summary: summarize(results)
    }
  end

  @doc """
  Returns the default external workspace path used for downloads and output.
  """
  @spec default_workspace() :: Path.t()
  def default_workspace do
    Path.join(System.tmp_dir!(), "zeal_docsets_workspace")
  end

  @doc """
  Filters dependencies by package name when a package filter is provided.

  When `packages` is empty, the original dependency list is returned.
  """
  @spec filter_packages([map()], [String.t()]) :: list()
  def filter_packages(deps, []), do: deps
  def filter_packages(deps, packages), do: Enum.filter(deps, &(&1.package in packages))

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  @doc false
  @spec print_progress(progress_event()) :: :ok
  def print_progress({:resolving_extra_package, spec, package, nil}) do
    IO.puts("Resolving #{spec} from Hex.pm as #{package}...")
  end

  def print_progress({:resolving_extra_package, spec, package, version}) do
    IO.puts("Using explicit version for #{spec}: #{package} #{version}...")
  end

  def print_progress({:resolved_extra_package, _spec, package, version}) do
    IO.puts("Resolved #{package} #{version}.")
  end

  def print_progress({:starting, package, version, index, total}) do
    IO.puts("[#{index}/#{total}] Starting #{package} #{version}...")
  end

  def print_progress({:downloading, package, version}) do
    IO.puts("Downloading docs for #{package} #{version}...")
  end

  def print_progress({:building, package, version}) do
    IO.puts("Building docset for #{package} #{version}...")
  end

  def print_progress({:installing, package, version, true}) do
    IO.puts("Installing #{package} #{version} into Zeal...")
  end

  def print_progress({:installing, _package, _version, false}), do: :ok

  def print_progress({:finished, package, version}) do
    IO.puts("Finished #{package} #{version}.")
  end

  def print_progress({:skipped, package, version}) do
    IO.puts("Skipping #{package} #{version}; docset is already up to date.")
  end

  def print_progress({:failed, package, version, message}) do
    IO.puts(:stderr, "Failed #{package} #{version}: #{message}")
  end

  defp notify(nil, _event), do: :ok
  defp notify(progress_fn, event), do: progress_fn.(event)

  @doc """
  Summarizes build results into built, skipped, and failed counts.
  """
  @spec summarize([result()]) :: summary()
  def summarize(results) do
    %{
      built: Enum.count(results, &match?({:ok, _, _}, &1)),
      skipped: Enum.count(results, &match?({:skipped, _, _}, &1)),
      failed: Enum.count(results, &match?({:error, _, _}, &1))
    }
  end

  defp collect_missing_icons(results) do
    results
    |> Enum.flat_map(fn
      {status, package, docset_path} when status in [:ok, :skipped] ->
        if File.exists?(Path.join(docset_path, "icon.png")), do: [], else: [package]

      _other ->
        []
    end)
    |> Enum.sort()
  end
end
