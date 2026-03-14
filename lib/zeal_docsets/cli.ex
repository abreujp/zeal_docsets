defmodule ZealDocsets.CLI do
  @moduledoc """
  Shared argument parsing and report rendering helpers used by
  `mix zeal.docs`.

  This module is not the primary public entrypoint of the package. The
  recommended interface is the Mix task installed via `mix archive.install`.
  """

  alias ZealDocsets.Docset
  alias ZealDocsets.Runner

  @switches [
    concurrency: :integer,
    dev: :boolean,
    force: :boolean,
    include_dev: :boolean,
    include_test: :boolean,
    no_install: :boolean,
    package: :keep,
    test: :boolean,
    workspace: :string
  ]

  @doc """
  Runs the docset generation pipeline and returns a structured result.
  """
  @spec run(Path.t(), Path.t(), keyword()) :: Runner.run_result()
  def run(project_path, zeal_path, opts) do
    Runner.run(project_path, zeal_path, opts)
  end

  @doc """
  Returns the default Zeal docsets path for the current platform.
  """
  @spec default_zeal_path() :: Path.t()
  def default_zeal_path, do: Docset.default_install_root()

  @doc """
  Parses CLI arguments into the project path, Zeal path, and options.
  """
  @spec parse_args([String.t()]) :: {:ok, Path.t(), Path.t(), keyword()} | {:error, String.t()}
  def parse_args(argv) do
    {opts, positional, invalid} = OptionParser.parse(argv, strict: @switches)

    with :ok <- validate_no_invalid_flags(invalid),
         {:ok, project_path, zeal_path} <- parse_positional(positional) do
      {:ok, project_path, zeal_path, opts}
    end
  end

  @doc """
  Prints a human-readable execution report.

  The report includes the execution settings, the build summary, an optional
  note about docsets without custom icons, and any package-level failures.
  """
  @spec print_report(Runner.run_result()) :: :ok
  def print_report(result) do
    print_header(result)

    if result.results == [] do
      IO.puts("No direct Hex dependencies found.")
    else
      print_summary(result)
    end

    :ok
  end

  @doc """
  Returns the process exit code for a run result.
  """
  @spec exit_code(Runner.run_result()) :: 0 | 1
  def exit_code(%{summary: %{failed: 0}}), do: 0
  def exit_code(_result), do: 1

  defp validate_no_invalid_flags([]), do: :ok
  defp validate_no_invalid_flags([{flag, _} | _]), do: {:error, "unknown option: #{flag}"}

  defp parse_positional([project_path]) do
    {:ok, Path.expand(project_path), default_zeal_path()}
  end

  defp parse_positional([project_path, zeal_path]) do
    {:ok, Path.expand(project_path), Path.expand(zeal_path)}
  end

  defp parse_positional(_other) do
    {:error, "expected one or two positional arguments: <project_path> [zeal_docsets_path]"}
  end

  defp print_header(result) do
    IO.puts("Project:      #{result.project_path}")
    IO.puts("Workspace:    #{result.workspace}")
    IO.puts("Zeal path:    #{result.zeal_path}")
    IO.puts("Install:      #{yes_no(result.install?)}")
    IO.puts("Concurrency:  #{result.concurrency}")
    IO.puts("Include dev:  #{yes_no(result.include_dev)}")
    IO.puts("Include test: #{yes_no(result.include_test)}")
    IO.puts("")
  end

  defp print_summary(%{summary: summary, results: results} = result) do
    IO.puts(
      "Summary: #{summary.built} built, #{summary.skipped} skipped, #{summary.failed} failed"
    )

    print_missing_icons(result)

    Enum.each(results, fn
      {:error, package, message} -> IO.puts(:stderr, "  x #{package}: #{message}")
      _other -> :ok
    end)
  end

  defp print_missing_icons(%{missing_icons: missing_icons}) when missing_icons != [] do
    IO.puts("Note: #{length(missing_icons)} docsets were generated without a custom icon.")
  end

  defp print_missing_icons(_result), do: :ok

  defp yes_no(true), do: "yes"
  defp yes_no(false), do: "no"
end
