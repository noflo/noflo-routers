# Migration notes: noflo-routers → @noflo/routers

Migrated 2026-10-09. 6 components, already JavaScript; converted to ES
modules and the 2.x Process API.

## Scope

- All 6 components converted; 10 `node:test` tests cover the 1.x spec
  scenarios (stream-position routing, GroupRouter routes/wildcards,
  KickRouter release semantics, PacketRegexpRouter matching and group
  persistence, sequencing).

## 2.x compatibility findings

- **GroupRouter's `packet.index` assignments were dead code in 1.x.**
  Its `out` port is not addressable, so setting `ip.index = match.index`
  had no effect in 1.x but is a hard error in 2.x (indexed sends to
  non-addressable ports are rejected). The assignments are dropped; the
  matching route is communicated on the `route` port as before.
- **GroupRouter's per-bracket `missed` flags were dead state.** The 1.x
  close-bracket path only forwarded to `missed` when the paired open
  bracket had been marked missed — which is always the case when the
  no-match branch is reached (the symmetric open marks it). The 2.x
  version forwards the close to `missed` unconditionally in that
  branch; behavior is identical.
- **PacketRouter's `missed` sends needed index stripping.** The
  addressable `in` port stamps connection indexes onto consumed
  packets; forwarding them to the non-addressable `missed` port fails
  in 2.x. The index is cleared before the missed send.
- **KickRouter buffers streams until release** (next/prev/index) — the
  2.x port preserves this: `hasStream` is checked but the stream is not
  consumed until a release control arrives. Data sent without any
  release signal stays buffered until teardown.
