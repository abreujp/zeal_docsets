defmodule ZealDocsets.Workspace do
  @moduledoc """
  Manages the workspace directory used for downloads and generated docsets.

  The workspace has the following layout:

      <root>/
      ├── downloads/   ← mirrored hexdocs HTML/assets
      └── output/      ← generated .docset bundles
  """

  @doc """
  Ensures the workspace directory and its required subdirectories exist.

  Expands `root` to an absolute path, creates `downloads/` and `output/`
  subdirectories if they do not exist, and returns the expanded root.

  Raises on filesystem errors.
  """
  @spec ensure!(Path.t()) :: Path.t()
  def ensure!(root) do
    root = Path.expand(root)

    for name <- ["downloads", "output"] do
      root
      |> Path.join(name)
      |> File.mkdir_p!()
    end

    root
  end
end
