# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Detect the default Zeal docsets directory by platform.
- Build temporary workspace files outside the project repository by default.
- Improve CLI ergonomics by allowing the Zeal path argument to be optional.

### Fixed

- Escape values written to `Info.plist` and `meta.json`.
- Handle missing URI paths defensively in the HexDocs crawler.
- Keep test output clean by capturing CLI report output correctly.

### Added

- Simple retry logic for transient HTTP failures.
- Additional CLI and runner test coverage.

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
