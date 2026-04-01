# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-04-01

### Added
- **Redis connection pooling** via NimblePool (`Cachetastic.Backend.RedisPool`) with configurable `pool_size`
- **Thundering herd protection** in `fetch` — per-key locking via `Cachetastic.Lock` ensures only one process computes the fallback
- **Key namespacing** — configurable `key_prefix` to avoid collisions in shared Redis instances
- **Pattern-based invalidation** — `delete_pattern/1-2` using Redis SCAN
- **Redis Pub/Sub adapter** — `Cachetastic.PubSub.RedisPubSub` for distributed invalidation without BEAM clustering
- **Dialyzer** — zero warnings, added `dialyxir` to dev dependencies

### Changed
- Version bump to 1.0.0 — stable public API

## [0.3.0] - 2026-04-01

### Added
- Redis connection pooling, thundering herd protection, key namespacing, pattern invalidation, Redis Pub/Sub adapter

### Fixed
- CI pipeline: updated `setup-beam` to v1, Elixir 1.18/OTP 27

## [0.2.0] - 2026-04-01

### Added
- OTP Application with proper supervision tree (Registry + DynamicSupervisor)
- Telemetry events for all cache operations
- Configurable serialization with pluggable behaviour (JSON + ErlangTerm)
- Multiple named caches with isolated storage
- `fetch/2-4` with fallback function
- Cache stats tracking via `Cachetastic.Stats`
- Multi-layer L1/L2 caching backend (`Cachetastic.Backend.MultiLayer`)
- Distributed pub/sub invalidation via Erlang `:pg`
- Ecto integration updated to use configurable serializer
- Typespecs on all public functions

### Fixed
- **Connection leak**: backends are now supervised GenServers started once
- **ETS TTL**: entries now expire via lazy check on read + active sweep
- **Config crash**: `backup_backend/0` no longer crashes without backup configured
- **Fault tolerance**: `:not_found` is never retried or fallen back on

### Changed
- Elixir requirement bumped to `~> 1.14`
- `Cachetastic.start_link/0` removed — app auto-starts via OTP

## [0.1.3] - 2024-07-10

### Added
- Ecto integration for caching query results
- ETS and Redis backends with fault tolerance
- Initial release on Hex
