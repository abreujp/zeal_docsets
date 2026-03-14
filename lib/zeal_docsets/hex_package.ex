defmodule ZealDocsets.HexPackage do
  @moduledoc false

  @doc false
  @spec validate_name!(String.t()) :: String.t()
  def validate_name!(package) do
    package = String.trim(package)

    if package != "" and String.match?(package, ~r/^[a-z0-9_][a-z0-9_-]*$/) do
      package
    else
      raise ArgumentError,
            "invalid Hex package name #{inspect(package)}; expected something like ecto or phoenix_live_view"
    end
  end
end
