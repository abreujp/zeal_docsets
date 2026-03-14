defmodule ZealDocsets.HTML do
  @moduledoc """
  Utility helpers for extracting text and attributes from Floki-parsed HTML.
  """

  @doc """
  Extracts and normalises the text content of a list of Floki nodes.

  Collapses consecutive whitespace into a single space, trims leading/trailing
  whitespace, and returns `nil` for empty or blank results.

  Returns `nil` when `nodes` is `nil`.
  """
  @spec text(Floki.html_tree() | nil) :: String.t() | nil
  def text(nil), do: nil

  def text(nodes) do
    nodes
    |> Floki.text(sep: " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> blank_to_nil()
  end

  @doc """
  Returns the value of `name` attribute from a single Floki node.

  Returns `nil` when the attribute is absent or its value is blank.
  """
  @spec attr(Floki.html_node(), String.t()) :: String.t() | nil
  def attr(node, name) do
    node
    |> Floki.attribute(name)
    |> List.first()
    |> blank_to_nil()
  end

  @doc """
  Returns `nil` for `nil` or empty string; passes other values through unchanged.
  """
  @spec blank_to_nil(String.t() | nil) :: String.t() | nil
  def blank_to_nil(nil), do: nil
  def blank_to_nil(""), do: nil
  def blank_to_nil(value), do: value
end
