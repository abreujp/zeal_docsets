defmodule ZealDocsets.HTMLTest do
  use ExUnit.Case, async: true

  alias ZealDocsets.HTML

  describe "text/1" do
    test "returns nil for nil" do
      assert HTML.text(nil) == nil
    end

    test "returns nil for empty node list" do
      assert HTML.text([]) == nil
    end

    test "returns trimmed text from nodes" do
      {:ok, doc} = Floki.parse_document("<span>  Hello  World  </span>")
      nodes = Floki.find(doc, "span")
      assert HTML.text(nodes) == "Hello World"
    end

    test "collapses internal whitespace" do
      {:ok, doc} = Floki.parse_document("<p>foo\n  bar\tbaz</p>")
      nodes = Floki.find(doc, "p")
      assert HTML.text(nodes) == "foo bar baz"
    end

    test "returns nil for blank text" do
      {:ok, doc} = Floki.parse_document("<span>   </span>")
      nodes = Floki.find(doc, "span")
      assert HTML.text(nodes) == nil
    end
  end

  describe "attr/2" do
    test "returns the attribute value" do
      {:ok, doc} = Floki.parse_document(~s(<a href="/foo">link</a>))
      [node] = Floki.find(doc, "a")
      assert HTML.attr(node, "href") == "/foo"
    end

    test "returns nil when attribute is absent" do
      {:ok, doc} = Floki.parse_document("<a>link</a>")
      [node] = Floki.find(doc, "a")
      assert HTML.attr(node, "href") == nil
    end

    test "returns nil when attribute value is empty" do
      {:ok, doc} = Floki.parse_document(~s(<a href="">link</a>))
      [node] = Floki.find(doc, "a")
      assert HTML.attr(node, "href") == nil
    end
  end

  describe "blank_to_nil/1" do
    test "passes non-blank strings through" do
      assert HTML.blank_to_nil("hello") == "hello"
    end

    test "converts empty string to nil" do
      assert HTML.blank_to_nil("") == nil
    end

    test "converts nil to nil" do
      assert HTML.blank_to_nil(nil) == nil
    end
  end
end
