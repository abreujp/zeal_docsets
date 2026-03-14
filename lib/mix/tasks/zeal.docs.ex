defmodule Mix.Tasks.Zeal.Docs do
  use Mix.Task

  alias ZealDocsets.CLI

  @shortdoc "Generate Zeal docsets from a Mix project's dependencies"

  @moduledoc """
  Generates Zeal/Dash-compatible docsets for the direct Hex dependencies of a
  Mix project.

  If `zeal_docsets_path` is omitted, the default Zeal directory for the current
  platform is used.

  ## Usage

      mix zeal.docs <project_path> [zeal_docsets_path] [options]

  ## Examples

      mix zeal.docs ~/projects/my_app
      mix zeal.docs ~/projects/my_app ~/.local/share/Zeal/Zeal/docsets --dev
      mix zeal.docs ~/projects/my_app --package phoenix --force
  """

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    case CLI.parse_args(args) do
      {:ok, project_path, zeal_path, opts} ->
        result = CLI.run(project_path, zeal_path, opts)
        CLI.print_report(result)

        if CLI.exit_code(result) != 0 do
          Mix.raise("one or more docsets failed to build")
        end

      {:error, message} ->
        Mix.raise("#{message}\n\n#{usage()}")
    end
  end

  defp usage do
    """
    Usage: mix zeal.docs <project_path> [zeal_docsets_path] [options]

    Options:
      --force           Regenerate even if version is up to date
      --dev             Include :dev-only dependencies
      --test            Include :test-only dependencies
      --no-install      Skip copying docsets to zeal_docsets_path
      --package NAME    Only build this package (repeatable)
      --workspace PATH  Custom workspace directory
      --concurrency N   Parallel builds (default: schedulers online)
    """
  end
end
