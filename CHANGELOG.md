# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.2] - 2026-03-14

### Fixed

- Remove the incorrect global-installation guidance and document the supported usage as a Mix development dependency.
- Reuse the current Mix project context when `mix zeal.docs` runs from inside the target project.

### Changed

- Stop documenting `escript` and Mix archive as supported distribution formats.
- Document `mix zeal.docs` as a task provided by adding `zeal_docsets` to a target project's development dependencies.

## [0.1.1] - 2026-03-14

### Changed

- Detect the default Zeal docsets directory by platform.
- Build temporary workspace files outside the project repository by default.
- Improve CLI ergonomics by allowing the Zeal path argument to be optional.
- Summarize missing custom icons at the end of a run instead of printing one warning per package.
- Move Dialyzer PLTs to `.dialyzer/` instead of `priv/`.
- Replace Sobelow with a quality toolchain tailored to this CLI/library project.

### Fixed

- Escape values written to `Info.plist` and `meta.json`.
- Handle missing URI paths defensively in the HexDocs crawler.
- Keep test output clean by capturing CLI report output correctly.
- Align HexDocs and inline documentation with the current CLI behavior.

### Added

- Simple retry logic for transient HTTP failures.
- Additional CLI and runner test coverage.
- `mix quality` alias combining formatting, compilation, tests, linting, auditing, documentation checks, and duplication checks.

## [0.1.0] - 2026-03-14

### Added

- Initial release.
- Read direct Hex dependencies from `mix.exs` and exact versions from `mix.lock`.
- Mirror HTML documentation from hexdocs.pm using a BFS crawler (pure Elixir,
  no external tools required).
- Generate Zeal/Dash-compatible `.docset` bundles with:
  - `Contents/Info.plist` (Apple plist format)
  - `Contents/Resources/docSet.dsidx` (SQLite search index)
  - `Contents/Resources/Documents/docs/{package}/` (mirrored HTML)
  - `icon.png` / `icon@2x.png` (package logo when available)
  - `meta.json` (name, title, version)
- Search index covers Modules, Commands (Mix tasks), Functions, Types,
  Callbacks, Macros, and Guides.
- Skip regeneration when the installed version already matches the locked
  version (with `--force` to override).
- Parallel docset generation via `Task.async_stream`.
- `--dev` and `--test` flags to include non-production dependencies.
- `--package` flag (repeatable) to build only specific packages.
- Available both as a standalone escript (`zeal_docsets`) and as a Mix task
  (`mix zeal.docs`).
