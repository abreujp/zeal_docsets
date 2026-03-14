# ZealDocsets

[![Hex.pm](https://img.shields.io/hexpm/v/zeal_docsets.svg)](https://hex.pm/packages/zeal_docsets)
[![CI](https://github.com/abreujp/zeal_docsets/actions/workflows/ci.yml/badge.svg)](https://github.com/abreujp/zeal_docsets/actions/workflows/ci.yml)

Generate offline [Zeal](https://zealdocs.org/) / [Dash](https://kapeli.com/dash)
docsets from the direct Hex dependencies of any Mix project.

`zeal_docsets` reads a target project's `mix.exs` to discover direct
Hex dependencies, cross-references `mix.lock` for the exact locked versions,
and downloads the HTML documentation from [hexdocs.pm](https://hexdocs.pm)
using a pure-Elixir crawler. The original HexDocs UI is preserved in the
generated docsets.

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
- Summarises docsets generated without a custom icon instead of printing one warning per package.
- Works as an escript (`zeal_docsets`) or a Mix task (`mix zeal.docs`).

## Installation

`zeal_docsets` supports Elixir `~> 1.17` and newer.

Install the escript globally:

```bash
mix escript.install hex zeal_docsets
```

Build it from source locally:

```bash
mix deps.get
mix escript.build
./zeal_docsets ~/projects/my_app
```

## Usage

### As a standalone binary

```bash
zeal_docsets <project_path> [zeal_docsets_path] [options]
```

### As a Mix task

```bash
mix zeal.docs <project_path> [zeal_docsets_path] [options]
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
| `--workspace PATH` | Custom workspace directory for downloads and output |
| `--concurrency N` | Parallel builds (default: number of schedulers online) |

## Examples

```bash
# Production dependencies only
zeal_docsets ~/projects/my_app

# Include development dependencies too
zeal_docsets ~/projects/my_app --dev

# Include development and test dependencies
zeal_docsets ~/projects/my_app --dev --test

# Use an explicit Zeal path
zeal_docsets ~/projects/my_app ~/.local/share/Zeal/Zeal/docsets

# Regenerate only phoenix
zeal_docsets ~/projects/my_app --package phoenix --force

# Build without installing
zeal_docsets ~/projects/my_app --no-install

# Generate docsets for all direct deps, including dev and test deps
mix zeal.docs ~/projects/my_app --dev --test --force --concurrency 6
```

## How it works

1. Dependency discovery - `mix.exs` is loaded in an isolated Mix context.
2. Version resolution - `mix.lock` is parsed to obtain exact locked versions.
3. Filtering - git/path dependencies are excluded because they do not map cleanly to `hexdocs.pm`.
4. Mirroring - HTML, CSS, JavaScript, fonts, and image assets are downloaded from `hexdocs.pm`.
5. Packaging - the mirrored files are assembled into a `.docset` bundle.
6. Indexing - a SQLite search index is generated for modules, functions, types, callbacks, macros, commands, and guides.
7. Installation - the docset is copied to the Zeal docsets directory unless `--no-install` is used.

## Limitations

- Git and path dependencies are ignored.
- Some packages do not publish versioned docs on `hexdocs.pm`.
- Some packages do not provide a `logo.png`, so their docset has no custom icon.
- The default workspace lives outside the repository in the system temp directory.

## Roadmap

- Improve `mix.lock` parsing robustness.
- Add optional download caching between runs.
- Add more verbose progress reporting for long downloads.

## Development

```bash
mix deps.get
mix format
mix test
mix quality
mix dialyzer
mix escript.build
```

## License

MIT - see [LICENSE](LICENSE).
