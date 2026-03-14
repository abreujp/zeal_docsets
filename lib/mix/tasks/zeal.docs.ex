defmodule Mix.Tasks.Zeal.Docs do
  use Mix.Task

  alias ZealDocsets.CLI

  @shortdoc "Generate Zeal docsets from a Mix project's dependencies"

  @moduledoc """
  Generates Zeal/Dash-compatible docsets for the direct Hex dependencies of the
  current Mix project, with optional extra Hex packages requested explicitly.

  The supported workflow is to run this task from the target project's root and
  pass `.` as the project path. If `zeal_docsets_path` is omitted, the default
  Zeal directory for the current platform is used.

  ## Usage

      mix zeal.docs . [zeal_docsets_path] [options]

  ## Examples

      mix zeal.docs .
      mix zeal.docs . ~/.local/share/Zeal/Zeal/docsets --dev
      mix zeal.docs . --dev --test --force --concurrency 6
      mix zeal.docs . --package phoenix --force
      mix zeal.docs . --extra-package ecto
      mix zeal.docs . --extra-package phoenix_live_view@1.1.16
  """

  @impl true
  def run(args) do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:mix)
    Application.ensure_all_started(:exqlite)

    case CLI.parse_args(args) do
      {:ok, project_path, zeal_path, opts} ->
        result =
          CLI.run(
            project_path,
            zeal_path,
            Keyword.put(opts, :current_project, current_project?(project_path))
          )

        CLI.print_report(result)

        if CLI.exit_code(result) != 0 do
          Mix.raise("one or more docsets failed to build")
        end

      {:error, message} ->
        Mix.raise("#{message}\n\n#{usage()}")
    end
  end

  defp current_project?(project_path) do
    Mix.Project.get() != nil and
      Path.expand(project_path, File.cwd!()) == Path.expand(File.cwd!())
  end

  defp usage do
    """
    Usage: mix zeal.docs . [zeal_docsets_path] [options]

    Options:
      --force           Regenerate even if version is up to date
      --dev             Include :dev-only dependencies
      --test            Include :test-only dependencies
      --no-install      Generate docsets without copying them to the Zeal directory
      --package NAME    Only build this package (repeatable)
      --extra-package SPEC
                        Also build a Hex package not declared in mix.exs.
                        Accepts package or package@version and is repeatable.
      --workspace PATH  Custom workspace directory
      --concurrency N   Parallel builds (default: schedulers online)
    """
  end
end
