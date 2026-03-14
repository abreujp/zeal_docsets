defmodule ZealDocsets do
  @moduledoc """
  `ZealDocsets` generates offline documentation bundles (docsets) for
  [Zeal](https://zealdocs.org/) and [Dash](https://kapeli.com/dash) from
  the direct Hex dependencies of any Mix project.

  It reads `mix.exs` to discover which packages the project directly depends
  on, then cross-references `mix.lock` for the exact locked versions.
  For each package it mirrors the HTML documentation from
  [hexdocs.pm](https://hexdocs.pm) and packages it into a `.docset` bundle
  ready to be imported into Zeal.

  ## Usage as a project dependency

      # In the target project's mix.exs
      {:zeal_docsets, "~> 0.1.2", only: :dev, runtime: false}

      # Then inside the target project
      mix zeal.docs . [zeal_docsets_path] [options]

  See `ZealDocsets.CLI` for the full list of options.
  """
end
