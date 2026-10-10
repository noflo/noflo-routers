# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [2.0.0-alpha.1] - 2026-10-09

### Added

- The package is renamed to `@noflo/routers`; graph component identifiers are unaffected and keep resolving under the `routers/` namespace

### Changed

- All 6 components are converted to JavaScript ES modules for NoFlo 2.x (esm-only), with TypeScript-checked sources and Biome formatting
- Components follow the 2.x Process API contract: preconditions are checked with `has`/`hasData`/`hasStream` before any `get`/`getData` call, and per-scope state is kept in Maps cleared in async `tearDown`
- `GroupRouter` no longer assigns route indexes onto forwarded packet IPs: its `out` port is not addressable, so the 1.x assignment was dead code — the matching route is communicated on the `route` port. The 1.x per-bracket `missed` object flags (object-identity state) are likewise dropped; the close-bracket path forwards to `missed` exactly when the 1.x flags were set
- `PacketRouter` clears the source connection index on packets forwarded to the non-addressable `missed` port (2.x rejects indexed sends there)

### Fixed

- Test suite rebuilt on `node:test` (10 tests), covering the 1.x spec scenarios: stream-position routing with missed positions, the full GroupRouter route/wildcard scenario, KickRouter buffered-stream release via next/prev/index (with wraparound), PacketRegexpRouter matching/mismatch/group persistence, round-robin and controlled sequencing
