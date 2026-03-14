defmodule ZealDocsets.HexdocsTest do
  use ExUnit.Case, async: true

  alias ZealDocsets.Hexdocs

  describe "required_resource?/1" do
    test "keeps the root and index pages as required" do
      assert Hexdocs.required_resource?("/")
      assert Hexdocs.required_resource?("/ecto/3.13.5/index.html")
    end

    test "treats discovered html pages as optional" do
      refute Hexdocs.required_resource?("/ash/3.19.3/dsl-ash-domain-info.html")
      refute Hexdocs.required_resource?("/ash/3.19.3/some/guide.html")
      refute Hexdocs.required_resource?("/jido_action/2.1.0/api-reference.html")
    end
  end

  describe "extract_meta_refresh_target/1" do
    test "extracts the redirected html page from a meta refresh tag" do
      html = ~s(<meta http-equiv="refresh" content="0; url=readme.html">)

      assert Hexdocs.extract_meta_refresh_target(html) == "readme.html"
    end

    test "returns nil when there is no meta refresh tag" do
      assert Hexdocs.extract_meta_refresh_target("<html><body>ok</body></html>") == nil
    end
  end
end
