defmodule ZealDocsets.HexPm do
  @moduledoc """
  Fetches package metadata from the Hex.pm API.

  This module is used to resolve versions for `--extra-package` entries that do
  not exist in the target project's `mix.exs` or `mix.lock`.
  """

  @user_agent ~c"zeal_docsets/0.1"
  @request_timeout 30_000
  @connect_timeout 10_000
  @retry_attempts 3
  @retry_delay_ms 250

  @doc """
  Returns the latest stable version published for `package` on Hex.pm.

  Raises a `RuntimeError` if the package does not exist or if Hex.pm cannot be
  reached.
  """
  @spec latest_stable_version!(String.t()) :: String.t()
  def latest_stable_version!(package), do: latest_stable_version!(package, [])

  @doc false
  @spec latest_stable_version!(String.t(), keyword()) :: String.t()
  def latest_stable_version!(package, opts) do
    request_fn = Keyword.get(opts, :request_fn, &request/1)
    package = ZealDocsets.HexPackage.validate_name!(package)

    package
    |> package_api_url()
    |> request_fn.()
    |> handle_version_response!(package)
  end

  @doc false
  @spec handle_version_response!({:ok, String.t()} | {:error, term()}, String.t()) :: String.t()
  def handle_version_response!({:ok, body}, package) do
    extract_latest_stable_version!(body, package)
  end

  def handle_version_response!({:error, :not_found}, package) do
    raise "package #{package} not found on hex.pm"
  end

  def handle_version_response!({:error, reason}, package) do
    raise "could not reach hex.pm for #{package}: #{inspect(reason)}"
  end

  @doc false
  @spec extract_latest_stable_version!(String.t(), String.t()) :: String.t()
  def extract_latest_stable_version!(body, package) do
    case Regex.run(~r/"latest_stable_version"\s*:\s*"([^"]+)"/, body, capture: :all_but_first) do
      [version] when version != "" -> version
      _other -> raise "could not determine the latest stable version for #{package} from hex.pm"
    end
  end

  defp request(url) do
    do_request(url, @retry_attempts)
  end

  defp do_request(url, attempts_left) do
    case :httpc.request(
           :get,
           {String.to_charlist(url), [{~c"user-agent", @user_agent}]},
           [autoredirect: true, timeout: @request_timeout, connect_timeout: @connect_timeout],
           body_format: :binary
         ) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        {:ok, body}

      {:ok, {{_, 404, _}, _headers, _body}} ->
        {:error, :not_found}

      {:ok, {{_, status, _}, _headers, _body}} ->
        {:error, {:http_error, status}}

      {:error, _reason} when attempts_left > 1 ->
        Process.sleep(@retry_delay_ms)
        do_request(url, attempts_left - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  @spec package_api_url(String.t()) :: String.t()
  def package_api_url(package), do: "https://hex.pm/api/packages/#{package}"
end
