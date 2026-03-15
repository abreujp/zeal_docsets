defmodule ZealDocsets.HexdocsTest do
  use ExUnit.Case, async: true

  alias ZealDocsets.Hexdocs

  describe "required_resource?/1" do
    test "keeps the root path as required" do
      assert Hexdocs.required_resource?("/")
    end

    test "keeps any index.html as required" do
      assert Hexdocs.required_resource?("/ecto/3.13.5/index.html")
      assert Hexdocs.required_resource?("/phoenix/1.8.4/index.html")
    end

    test "treats arbitrary HTML pages as optional" do
      refute Hexdocs.required_resource?("/ash/3.19.3/dsl-ash-domain-info.html")
      refute Hexdocs.required_resource?("/ash/3.19.3/some/guide.html")
    end

    test "treats api-reference.html as optional (seeded separately)" do
      refute Hexdocs.required_resource?("/jido_action/2.1.0/api-reference.html")
    end

    test "treats non-html assets as optional" do
      refute Hexdocs.required_resource?("/ecto/3.13.5/dist/app.js")
      refute Hexdocs.required_resource?("/ecto/3.13.5/assets/logo.png")
    end
  end

  describe "extract_meta_refresh_target/1" do
    test "extracts target URL from meta refresh with double quotes" do
      html = ~s(<meta http-equiv="refresh" content="0; url=readme.html">)
      assert Hexdocs.extract_meta_refresh_target(html) == "readme.html"
    end

    test "extracts target URL from meta refresh with single quotes" do
      html = ~s(<meta http-equiv='refresh' content='0; url=changelog.html'>)
      assert Hexdocs.extract_meta_refresh_target(html) == "changelog.html"
    end

    test "is case-insensitive on the http-equiv attribute" do
      html = ~s(<meta http-equiv="Refresh" content="0; url=intro.html">)
      assert Hexdocs.extract_meta_refresh_target(html) == "intro.html"
    end

    test "trims whitespace around the URL" do
      html = ~s(<meta http-equiv="refresh" content="0; url= readme.html ">)
      assert Hexdocs.extract_meta_refresh_target(html) == "readme.html"
    end

    test "returns nil when there is no meta refresh tag" do
      assert Hexdocs.extract_meta_refresh_target("<html><body>ok</body></html>") == nil
    end

    test "returns nil for empty string" do
      assert Hexdocs.extract_meta_refresh_target("") == nil
    end

    test "returns nil when content has no url= directive" do
      html = ~s(<meta http-equiv="refresh" content="5">)
      assert Hexdocs.extract_meta_refresh_target(html) == nil
    end
  end
end
