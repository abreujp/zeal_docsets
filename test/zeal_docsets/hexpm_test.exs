defmodule ZealDocsets.HexPmTest do
  use ExUnit.Case, async: true

  alias ZealDocsets.HexPm

  describe "latest_stable_version!/2" do
    test "returns the latest stable version from the Hex.pm payload" do
      body = ~s({"name":"ecto","latest_stable_version":"3.13.5"})

      request_fn = fn "https://hex.pm/api/packages/ecto" -> {:ok, body} end

      assert HexPm.latest_stable_version!("ecto", request_fn: request_fn) == "3.13.5"
    end

    test "raises for packages not found on Hex.pm" do
      request_fn = fn _url -> {:error, :not_found} end

      assert_raise RuntimeError, ~r/package ecto not found on hex.pm/, fn ->
        HexPm.latest_stable_version!("ecto", request_fn: request_fn)
      end
    end

    test "raises for other Hex.pm request errors" do
      request_fn = fn _url -> {:error, {:http_error, 500}} end

      assert_raise RuntimeError, ~r/could not reach hex.pm for ecto/, fn ->
        HexPm.latest_stable_version!("ecto", request_fn: request_fn)
      end
    end

    test "raises when the Hex.pm payload does not expose latest_stable_version" do
      request_fn = fn _url -> {:ok, ~s({"name":"ecto"})} end

      assert_raise RuntimeError, ~r/could not determine the latest stable version for ecto/, fn ->
        HexPm.latest_stable_version!("ecto", request_fn: request_fn)
      end
    end

    test "validates package names before issuing requests" do
      request_fn = fn _url ->
        flunk("request_fn should not be called for invalid package names")
      end

      assert_raise ArgumentError, ~r/invalid Hex package name/, fn ->
        HexPm.latest_stable_version!("invalid package", request_fn: request_fn)
      end
    end
  end

  describe "handle_version_response!/2" do
    test "returns the extracted version for successful responses" do
      assert HexPm.handle_version_response!({:ok, ~s({"latest_stable_version":"1.2.3"})}, "ecto") ==
               "1.2.3"
    end

    test "raises for not found responses" do
      assert_raise RuntimeError, ~r/package ecto not found on hex.pm/, fn ->
        HexPm.handle_version_response!({:error, :not_found}, "ecto")
      end
    end

    test "raises for generic error responses" do
      assert_raise RuntimeError, ~r/could not reach hex.pm for ecto/, fn ->
        HexPm.handle_version_response!({:error, :timeout}, "ecto")
      end
    end
  end

  describe "extract_latest_stable_version!/2" do
    test "extracts the version from the payload" do
      assert HexPm.extract_latest_stable_version!(~s({"latest_stable_version":"0.9.0"}), "ash") ==
               "0.9.0"
    end

    test "raises when the version field is empty" do
      assert_raise RuntimeError, ~r/could not determine the latest stable version for ash/, fn ->
        HexPm.extract_latest_stable_version!(~s({"latest_stable_version":""}), "ash")
      end
    end
  end

  describe "package_api_url/1" do
    test "builds the Hex.pm package metadata URL" do
      assert HexPm.package_api_url("ecto") == "https://hex.pm/api/packages/ecto"
    end
  end

  describe "latest_stable_version!/1 (1-arity public entry)" do
    test "calls the correct Hex.pm URL for the given package" do
      # Capture which URL is actually requested to confirm the 1-arity delegates properly
      body = ~s({"latest_stable_version":"1.16.1"})

      request_fn = fn url ->
        assert url == "https://hex.pm/api/packages/plug"
        {:ok, body}
      end

      assert HexPm.latest_stable_version!("plug", request_fn: request_fn) == "1.16.1"
    end
  end
end
