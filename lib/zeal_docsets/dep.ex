defmodule ZealDocsets.Dep do
  @moduledoc """
  Represents a resolved package selected for docset generation.

  A `Dep` is usually built by reading a project's `mix.exs` for direct
  dependencies and cross-referencing the exact locked version from `mix.lock`.
  It can also represent an extra Hex package requested explicitly from the CLI.

  ## Fields

  - `:app`         — The OTP application name (atom), e.g. `:phoenix`.
  - `:package`     — The Hex package name (string), e.g. `"phoenix"`.
  - `:requirement` — The version requirement string from `mix.exs`,
                     e.g. `"~> 1.8"`. May be `nil` for git/path deps.
  - `:version`     — The exact locked version string from `mix.lock`,
                     e.g. `"1.8.4"`. `nil` if not locked or not a Hex dep.
  - `:source`      — Where the dependency comes from: `:hex`, `:git`,
                     or `:path`.
  - `:envs`        — The Mix environments this dep belongs to,
                     e.g. `[:prod]`, `[:dev, :test]`. Defaults to `[:prod]`.
  """

  defstruct [:app, :package, :requirement, :version, :source, envs: [:prod]]

  @type t :: %__MODULE__{
          app: atom() | nil,
          package: String.t() | nil,
          requirement: String.t() | nil,
          version: String.t() | nil,
          source: :hex | :git | :path | nil,
          envs: [atom()]
        }
end
