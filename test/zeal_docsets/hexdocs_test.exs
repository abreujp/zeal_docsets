defmodule ZealDocsets.HexdocsTest do
  use ExUnit.Case, async: true

  alias ZealDocsets.Hexdocs

  describe "required_resource?/1" do
    test "keeps the root and key entry pages as required" do
      assert Hexdocs.required_resource?("/")
      assert Hexdocs.required_resource?("/ecto/3.13.5/index.html")
      assert Hexdocs.required_resource?("/ecto/3.13.5/api-reference.html")
    end

    test "treats discovered html pages as optional" do
      refute Hexdocs.required_resource?("/ash/3.19.3/dsl-ash-domain-info.html")
      refute Hexdocs.required_resource?("/ash/3.19.3/some/guide.html")
    end
  end
end
