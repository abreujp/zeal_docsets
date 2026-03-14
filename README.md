# ZealDocsets

[![Hex.pm](https://img.shields.io/hexpm/v/zeal_docsets.svg)](https://hex.pm/packages/zeal_docsets)
[![CI](https://github.com/abreujp/zeal_docsets/actions/workflows/ci.yml/badge.svg)](https://github.com/abreujp/zeal_docsets/actions/workflows/ci.yml)

Generate offline [Zeal](https://zealdocs.org/) / [Dash](https://kapeli.com/dash)
docsets from the direct Hex dependencies of any Mix project, with optional
extra packages fetched from Hex.pm.

`zeal_docsets` reads a target project's `mix.exs` to discover direct
Hex dependencies, cross-references `mix.lock` for the exact locked versions,
optionally appends extra Hex packages requested on the CLI, and downloads the
HTML documentation from [hexdocs.pm](https://hexdocs.pm) using a pure-Elixir
crawler. The original HexDocs UI is preserved in the generated docsets.

## Features

- Reads `mix.exs` + `mix.lock` - no manual version entry required.
- Pure Elixir HTTP crawler using OTP's built-in `:httpc`.
- Simple retry logic for transient network failures.
- Generates valid `.docset` bundles with mirrored HTML, `Info.plist`,
  `meta.json`, and a SQLite search index.
- Builds docsets in parallel.
- Skips packages already at the correct version unless `--force` is used.
- Installs directly into Zeal's docsets directory.
- Supports production-only mode by default, with optional `--dev` and `--test`.
- Supports `--extra-package` for packages that are not declared in `mix.exs`.
- Summarises docsets generated without a custom icon instead of printing one warning per package.
- Integrates into a target Mix project as a development dependency.

## Installation

`zeal_docsets` supports Elixir `~> 1.17` and newer.

Add `zeal_docsets` to the target project's `mix.exs`:

```elixir
defp deps do
  [
    {:zeal_docsets, "~> 0.1.6", only: [:dev, :test], runtime: false}
  ]
end
```

Then fetch dependencies inside the target project:

```bash
mix deps.get
```

## Common setup issue

If the target project depends on `floki` only in `:test`, `mix zeal.docs` can
fail when run from the usual `:dev` environment. In that case, expose `floki`
to both environments:

```elixir
{:floki, ">= 0.37.0", only: [:dev, :test]}
```

This is the same fix you would apply when the task works in tests but fails in
development.

## Usage

Run the task from inside the target project. The supported workflow is to execute it from the project's root and pass `.` as the project path:

```bash
mix zeal.docs . [zeal_docsets_path] [options]
```

If `zeal_docsets_path` is omitted, a platform-specific Zeal directory is used:

- Linux: `~/.local/share/Zeal/Zeal/docsets`
- macOS: `~/Library/Application Support/Zeal/Zeal/docsets`
- Windows: `%APPDATA%/Zeal/Zeal/docsets`

By default, temporary downloads and generated docsets are built in an external
workspace under the system temp directory, not inside the project repository.
Use `--workspace PATH` only if you want to override that location.

## Options

| Flag | Description |
|------|-------------|
| `--force` | Regenerate even if version is already up to date |
| `--dev` | Include `:dev` dependencies |
| `--test` | Include `:test` dependencies |
| `--no-install` | Generate docsets but skip copying to the Zeal directory |
| `--package NAME` | Only build this package (repeatable) |
| `--extra-package SPEC` | Build only this extra Hex package when no `--package` filter is given; accepts `name` or `name@version` |
| `--workspace PATH` | Custom workspace directory for downloads and output |
| `--concurrency N` | Parallel builds (default: number of schedulers online) |

## Examples

```bash
# Production dependencies only
mix zeal.docs .

# Include development dependencies too
mix zeal.docs . --dev

# Include development and test dependencies
mix zeal.docs . --dev --test

# Use an explicit Zeal path
mix zeal.docs . ~/.local/share/Zeal/Zeal/docsets

# Regenerate only phoenix
mix zeal.docs . --package phoenix --force

# Fetch only ecto even if the project does not depend on it directly
mix zeal.docs . --extra-package ecto

# Fetch only a specific version from Hex.pm
mix zeal.docs . --extra-package phoenix_live_view@1.1.16

# Replace an existing docset with another version of the same package
mix zeal.docs . --extra-package ash@3.19.2 --force

# Build without installing
mix zeal.docs . --no-install

# Generate docsets for all direct deps, including dev and test deps
mix zeal.docs . --dev --test --force --concurrency 6
```

## How it works

1. Dependency discovery - `mix.exs` is loaded in an isolated Mix context.
2. Version resolution - `mix.lock` is parsed to obtain exact locked versions.
3. Extra package resolution - any `--extra-package` entries are resolved from Hex.pm, using the latest stable version by default when no version is specified.
4. Filtering - git/path dependencies are excluded because they do not map cleanly to `hexdocs.pm`. When `--extra-package` is used without `--package`, only the explicitly requested extra packages are built.
5. Mirroring - HTML, CSS, JavaScript, fonts, and image assets are downloaded from `hexdocs.pm`, with textual progress updates for long-running downloads.
6. Packaging - the mirrored files are assembled into a `.docset` bundle.
7. Indexing - a SQLite search index is generated for modules, functions, types, callbacks, macros, commands, and guides.
8. Installation - the docset is copied to the Zeal docsets directory unless `--no-install` is used.

## Limitations

- Git and path dependencies are ignored.
- Some packages do not publish versioned docs on `hexdocs.pm`.
- Some packages do not provide a `logo.png`, so their docset has no custom icon.
- The default workspace lives outside the repository in the system temp directory.
- If a target project already pins `floki` only for `:test`, it may need to expose `floki` in `:dev` too so `mix zeal.docs` can run from the development environment.

## Roadmap

- Improve `mix.lock` parsing robustness.
- Add optional download caching between runs.
- Add richer progress reporting beyond the current textual updates.

## Development

```bash
mix deps.get
mix format
mix test
mix quality
mix dialyzer
```

## License

MIT - see [LICENSE](LICENSE).
