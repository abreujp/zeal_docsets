defmodule ZealDocsets.HexPackageTest do
  use ExUnit.Case, async: true

  alias ZealDocsets.HexPackage

  describe "validate_name!/1" do
    test "returns trimmed valid package names" do
      assert HexPackage.validate_name!(" ecto_sql ") == "ecto_sql"
    end

    test "accepts hyphenated package names" do
      assert HexPackage.validate_name!("some-package") == "some-package"
    end

    test "raises for invalid package names" do
      assert_raise ArgumentError, ~r/invalid Hex package name/, fn ->
        HexPackage.validate_name!("bad package name")
      end
    end
  end
end
