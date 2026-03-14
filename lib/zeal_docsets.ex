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

  ## CLI usage (escript)

      zeal_docsets <project_path> <zeal_docsets_path> [options]

  ## Mix task usage

      mix zeal.docs <project_path> <zeal_docsets_path> [options]

  See `ZealDocsets.CLI` for the full list of options.
  """
end
