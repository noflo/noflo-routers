# @noflo/routers

Routing components for [NoFlo](http://noflojs.org/)

This package provides components for routing information packets in
NoFlo programs: by stream position, by groups, by regular expressions,
and by sequence.

## Usage

Install the package:

    npm install @noflo/routers

The components are then available under the `routers/` namespace, for
example `routers/PacketRouter` or `routers/GroupRouter`.

Components include:

- `PacketRouter` — route by stream position
- `PacketRegexpRouter` — route by regular expression match
- `GroupRouter` — route by group hierarchies with wildcard routes
- `KickRouter` — release buffered streams by index, prev, or next
- `SplitInSequence` — round-robin splitting
- `ControlledSequence` — switch connections on demand
