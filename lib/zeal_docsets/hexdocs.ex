defmodule ZealDocsets.Hexdocs do
  @moduledoc """
  Downloads and mirrors documentation from hexdocs.pm using a BFS crawler.

  Uses Erlang's built-in `:httpc` HTTP client with no external dependencies.
  Crawls HTML pages following local `href`, `src`, and `action` attributes,
  and CSS files following `url(...)` references. Only assets within the same
  package/version path prefix are downloaded.
  """

  @tracked_attributes ["href", "src", "action"]
  @user_agent ~c"zeal_docsets/0.1"
  @ignored_extensions [".epub", ".pdf", ".zip", ".tar", ".gz"]
  @request_timeout 30_000
  @connect_timeout 10_000
  @retry_attempts 3
  @retry_delay_ms 250

  @doc """
  Mirrors the documentation for `package` at `version` into `downloads_root`.

  Downloads all HTML pages, stylesheets, and binary assets (images, fonts,
  scripts) from `https://hexdocs.pm/{package}/{version}/` using a BFS crawl.
  Returns the local root path where the mirrored files were saved.

  Raises if the package/version is not found on hexdocs.pm, or if a required
  resource (any HTML page or the root index) fails to download.
  """
  @spec mirror(String.t(), String.t(), Path.t()) :: Path.t()
  def mirror(package, version, downloads_root) do
    ensure_version!(package, version)

    root = Path.join([downloads_root, package, version])
    File.rm_rf!(root)
    File.mkdir_p!(root)

    base_uri = URI.parse(base_url(package, version) <> "/")
    base_path = base_uri.path || "/"

    # Seed the queue with the index and api-reference so both are always fetched
    # even if the index page does not link to api-reference directly.
    initial_paths = [base_path, URI.merge(base_uri, "api-reference.html") |> Map.get(:path)]
    queue = :queue.from_list(Enum.uniq(initial_paths))
    visited = %{}

    crawl(queue, visited, base_uri, root)
    root
  end

  @doc """
  Checks whether `version` of `package` exists on hexdocs.pm.

  Raises a `RuntimeError` with a descriptive message if the version is not
  found (HTTP 4xx) or if the network request fails.
  """
  @spec ensure_version!(String.t(), String.t()) :: :ok
  def ensure_version!(package, version) do
    url = base_url(package, version) <> "/"

    case request(:head, url) do
      {:ok, {{_, status, _}, _headers, _body}} when status in 200..399 ->
        :ok

      {:ok, {{_, status, _}, _headers, _body}} ->
        raise "version #{version} of package #{package} not found on hexdocs.pm (HTTP #{status})"

      {:error, reason} ->
        raise "could not reach hexdocs.pm for #{package} #{version}: #{inspect(reason)}"
    end
  end

  # ---------------------------------------------------------------------------
  # BFS crawler
  # ---------------------------------------------------------------------------

  @spec crawl(:queue.queue(String.t()), %{optional(String.t()) => true}, URI.t(), Path.t()) :: :ok
  defp crawl(queue, visited, base_uri, root) do
    case :queue.out(queue) do
      {:empty, _} ->
        :ok

      {{:value, relative_path}, rest} ->
        crawl_next(relative_path, rest, visited, base_uri, root)
    end
  end

  @spec crawl_next(
          String.t(),
          :queue.queue(String.t()),
          %{optional(String.t()) => true},
          URI.t(),
          Path.t()
        ) ::
          :ok
  defp crawl_next(relative_path, rest, visited, base_uri, root) do
    if Map.has_key?(visited, relative_path) do
      crawl(rest, visited, base_uri, root)
    else
      content_type = fetch_file(relative_path, base_uri, root)
      derived = derived_paths(content_type, relative_path, root, base_uri)
      next_queue = enqueue_unvisited(rest, derived, visited)
      crawl(next_queue, Map.put(visited, relative_path, true), base_uri, root)
    end
  end

  defp fetch_file(relative_path, base_uri, root) do
    url =
      base_uri
      |> URI.merge(relative_path)
      |> encode_uri()
      |> URI.to_string()

    case request(:get, url) do
      {:ok, {{_, 200, _}, headers, body}} ->
        dest = destination_path(relative_path, root, base_uri)
        File.mkdir_p!(Path.dirname(dest))
        File.write!(dest, body)
        content_kind(headers, relative_path)

      {:ok, {{_, status, _}, _headers, _body}} ->
        if required_resource?(relative_path) do
          raise "failed to download #{url}: HTTP #{status}"
        else
          :skipped
        end

      {:error, reason} ->
        if required_resource?(relative_path) do
          raise "failed to download #{url}: #{inspect(reason)}"
        else
          :skipped
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Link extraction
  # ---------------------------------------------------------------------------

  defp extract_html_paths(relative_path, root, base_uri) do
    html =
      relative_path
      |> destination_path(root, base_uri)
      |> File.read!()

    doc = Floki.parse_document!(html)

    attr_paths =
      doc
      |> Floki.find("*")
      |> Enum.flat_map(fn node ->
        Enum.flat_map(@tracked_attributes, &attribute_paths(node, &1, relative_path, base_uri))
      end)

    meta_refresh_paths =
      html
      |> extract_meta_refresh_target()
      |> resolve_path(relative_path, base_uri)

    (attr_paths ++ meta_refresh_paths)
    |> Enum.uniq()
  end

  defp extract_css_paths(relative_path, root, base_uri) do
    relative_path
    |> destination_path(root, base_uri)
    |> File.read!()
    |> then(&Regex.scan(~r/url\(\s*['"]?([^'")\s]+)['"]?\s*\)/, &1, capture: :all_but_first))
    |> Enum.flat_map(fn [value] -> resolve_path(value, relative_path, base_uri) end)
    |> Enum.uniq()
  end

  defp resolve_path(value, current_path, base_uri) do
    if ignored_reference?(value) do
      []
    else
      current_abs = URI.merge(base_uri, current_path)
      uri = URI.merge(current_abs, value)

      if allowed_uri?(uri, base_uri) do
        [uri.path]
      else
        []
      end
    end
  end

  @spec derived_paths(atom(), String.t(), Path.t(), URI.t()) :: [String.t()]
  defp derived_paths(:html, relative_path, root, base_uri),
    do: extract_html_paths(relative_path, root, base_uri)

  defp derived_paths(:css, relative_path, root, base_uri),
    do: extract_css_paths(relative_path, root, base_uri)

  defp derived_paths(_other, _relative_path, _root, _base_uri), do: []

  @spec enqueue_unvisited(
          :queue.queue(String.t()),
          [String.t()],
          %{optional(String.t()) => true}
        ) ::
          :queue.queue(String.t())
  defp enqueue_unvisited(queue, paths, visited) do
    Enum.reduce(paths, queue, fn path, acc ->
      if Map.has_key?(visited, path), do: acc, else: :queue.in(path, acc)
    end)
  end

  defp attribute_paths(node, attr, relative_path, base_uri) do
    case Floki.attribute(node, attr) do
      [value | _] -> resolve_path(value, relative_path, base_uri)
      _ -> []
    end
  end

  @doc false
  @spec extract_meta_refresh_target(String.t()) :: String.t() | nil
  def extract_meta_refresh_target(html) do
    case Regex.run(
           ~r/<meta[^>]+http-equiv=["']refresh["'][^>]+content=["'][^"']*url=([^"'>]+)["']/i,
           html,
           capture: :all_but_first
         ) do
      [target] -> String.trim(target)
      _ -> nil
    end
  end

  defp ignored_reference?(value) do
    value in [nil, ""] or String.starts_with?(value, ["mailto:", "javascript:", "data:", "#"])
  end

  defp allowed_uri?(uri, base_uri) do
    same_host? = uri.host == base_uri.host
    base_prefix = base_uri.path || "/"
    path = uri.path || ""

    same_host? and String.starts_with?(path, base_prefix) and not ignored_extension?(path)
  end

  # ---------------------------------------------------------------------------
  # Path helpers
  # ---------------------------------------------------------------------------

  defp destination_path(relative_path, root, base_uri) do
    base_prefix =
      (base_uri.path || "/")
      |> String.trim_trailing("/")

    # Strip the leading slash to get a path relative to the host
    local =
      relative_path
      |> String.trim_leading("/")
      |> normalize_trailing_slash()

    # Remove the package/version prefix so files are stored flat under `root`
    trimmed_prefix = String.trim_leading(base_prefix, "/")

    path_under_root =
      cond do
        local == trimmed_prefix ->
          "index.html"

        String.starts_with?(local, trimmed_prefix <> "/") ->
          String.slice(local, String.length(trimmed_prefix) + 1, String.length(local))

        true ->
          local
      end

    Path.join(root, path_under_root)
  end

  defp normalize_trailing_slash(""), do: "index.html"

  defp normalize_trailing_slash(path) do
    if String.ends_with?(path, "/"), do: path <> "index.html", else: path
  end

  defp content_kind(headers, relative_path) do
    content_type =
      Enum.find_value(headers, "", fn {key, val} ->
        if String.downcase(to_string(key)) == "content-type", do: to_string(val)
      end)

    cond do
      String.contains?(content_type, "text/html") or
        String.ends_with?(relative_path, ".html") or
          relative_path == "/" ->
        :html

      String.contains?(content_type, "text/css") or
          String.ends_with?(relative_path, ".css") ->
        :css

      true ->
        :binary
    end
  end

  @doc false
  @spec required_resource?(String.t()) :: boolean()
  def required_resource?("/"), do: true
  def required_resource?(path), do: String.ends_with?(path, "/index.html")

  defp ignored_extension?(path) do
    lower = String.downcase(path)
    Enum.any?(@ignored_extensions, &String.ends_with?(lower, &1))
  end

  # ---------------------------------------------------------------------------
  # HTTP
  # ---------------------------------------------------------------------------

  defp request(method, url) do
    do_request(method, url, @retry_attempts)
  end

  defp do_request(method, url, attempts_left) do
    case :httpc.request(
           method,
           {String.to_charlist(url), [{~c"user-agent", @user_agent}]},
           [autoredirect: true, timeout: @request_timeout, connect_timeout: @connect_timeout],
           body_format: :binary
         ) do
      {:error, _reason} when attempts_left > 1 ->
        Process.sleep(@retry_delay_ms)
        do_request(method, url, attempts_left - 1)

      result ->
        result
    end
  end

  defp encode_uri(%URI{} = uri) do
    %{uri | path: encode_path(uri.path), query: encode_query(uri.query)}
  end

  defp encode_path(nil), do: nil

  defp encode_path(path) do
    URI.encode(path, fn char -> URI.char_unreserved?(char) or char == ?/ end)
  end

  defp encode_query(nil), do: nil
  defp encode_query(query), do: URI.encode(query)

  defp base_url(package, version), do: "https://hexdocs.pm/#{package}/#{version}"
end
