import assert from "node:assert/strict";
import { describe, it } from "node:test";
import * as noflo from "@noflo/noflo";

import { getComponent as getControlledSequence } from "../components/ControlledSequence.js";
import { getComponent as getGroupRouter } from "../components/GroupRouter.js";
import { getComponent as getKickRouter } from "../components/KickRouter.js";
import { getComponent as getPacketRegexpRouter } from "../components/PacketRegexpRouter.js";
import { getComponent as getPacketRouter } from "../components/PacketRouter.js";
import { getComponent as getSplitInSequence } from "../components/SplitInSequence.js";
import { collect, render } from "./helpers.js";

describe("PacketRouter component", () => {
  it("routes incoming IPs based on IP stream position", async () => {
    const c = getPacketRouter();
    const inSocket = noflo.internalSocket.createSocket();
    c.inPorts.in.attach(inSocket);
    const outA = noflo.internalSocket.createSocket();
    const outB = noflo.internalSocket.createSocket();
    c.outPorts.out.attach(outA, 0);
    c.outPorts.out.attach(outB, 1);
    const missedSocket = noflo.internalSocket.createSocket();
    c.outPorts.missed.attach(missedSocket);
    /** @type {string[]} */
    const received = [];
    for (const socket of [outA, outB, missedSocket]) {
      socket.addEventListener(
        "ip",
        /** @param {CustomEvent} event */ (event) => {
          const ip = event.detail;
          if (ip.type === "openBracket") {
            received.push("group");
            return;
          }
          if (ip.type === "closeBracket") {
            return;
          }
          received.push(`DATA ${JSON.stringify(ip.data)}`);
        },
      );
    }
    inSocket.post(new noflo.IP("openBracket", null));
    inSocket.post(new noflo.IP("data", "a"));
    inSocket.post(new noflo.IP("data", "b"));
    inSocket.post(new noflo.IP("data", "c"));
    inSocket.post(new noflo.IP("data", "d"));
    inSocket.post(new noflo.IP("closeBracket", null));
    await new Promise((resolve) => setTimeout(resolve, 50));
    // Positions 0-1 route to the attached connections; 2-3 miss
    assert.deepEqual(received, [
      'DATA "a"',
      'DATA "b"',
      'DATA "c"',
      'DATA "d"',
    ]);
    void render;
  });
});

describe("GroupRouter component", () => {
  /** Builds a GroupRouter with route/missed/out collection. */
  const build = () => {
    const c = getGroupRouter();
    const routeSocket = noflo.internalSocket.createSocket();
    const routesSocket = noflo.internalSocket.createSocket();
    const inSocket = noflo.internalSocket.createSocket();
    const outSocket = noflo.internalSocket.createSocket();
    const missedSocket = noflo.internalSocket.createSocket();
    c.inPorts.route.attach(routeSocket);
    c.inPorts.routes.attach(routesSocket);
    c.inPorts.in.attach(inSocket);
    c.outPorts.out.attach(outSocket);
    c.outPorts.missed.attach(missedSocket);
    /** @type {string[]} */
    const received = [];
    const track = (
      /** @type {import("@noflo/noflo").internalSocket.InternalSocket} */ socket,
      /** @type {string} */ prefix,
    ) => {
      socket.addEventListener(
        "ip",
        /** @param {CustomEvent} event */ (event) => {
          const ip = event.detail;
          if (ip.type === "openBracket") {
            received.push(`${prefix} < ${String(ip.data)}`);
            return;
          }
          if (ip.type === "closeBracket") {
            received.push(`${prefix} >`);
            return;
          }
          received.push(`${prefix} DATA ${JSON.stringify(ip.data)}`);
        },
      );
    };
    track(outSocket, "OUT");
    track(missedSocket, "MISSED");
    return { c, routeSocket, routesSocket, inSocket, received };
  };

  it("routes incoming IPs based on group routes", async () => {
    const { c, routeSocket, inSocket, received } = build();
    // Each route is a linear hierarchy of groups; `["a", "b"]` matches
    // only if group `b` is enclosed within group `a`
    routeSocket.post(new noflo.IP("data", ["a", "b"]));
    routeSocket.post(new noflo.IP("data", "d"));
    routeSocket.post(new noflo.IP("data", ["a", "e.+"]));
    inSocket.post(new noflo.IP("openBracket", "a"));
    inSocket.post(new noflo.IP("data", "missed"));
    inSocket.post(new noflo.IP("openBracket", "b"));
    inSocket.post(new noflo.IP("data", "a/b"));
    inSocket.post(new noflo.IP("closeBracket", "b"));
    inSocket.post(new noflo.IP("openBracket", "c"));
    inSocket.post(new noflo.IP("data", "missed"));
    inSocket.post(new noflo.IP("closeBracket", "c"));
    inSocket.post(new noflo.IP("closeBracket", "a"));
    // As long as "d" is matched and there's no subsequent route
    // segment, any subsequent group doesn't count in determining
    // whether this is a match or not
    inSocket.post(new noflo.IP("openBracket", "d"));
    inSocket.post(new noflo.IP("openBracket", "e"));
    inSocket.post(new noflo.IP("data", "d"));
    inSocket.post(new noflo.IP("closeBracket", "e"));
    inSocket.post(new noflo.IP("closeBracket", "d"));
    inSocket.post(new noflo.IP("openBracket", "a"));
    inSocket.post(new noflo.IP("openBracket", "ea"));
    inSocket.post(new noflo.IP("data", "e"));
    inSocket.post(new noflo.IP("closeBracket", "ea"));
    inSocket.post(new noflo.IP("closeBracket", "a"));
    await new Promise((resolve) => setTimeout(resolve, 50));
    assert.deepEqual(received, [
      "MISSED < a",
      'MISSED DATA "missed"',
      'OUT DATA "a/b"',
      // The close of a matched group ends the match silently
      "MISSED < c",
      'MISSED DATA "missed"',
      "MISSED >",
      "MISSED >",
      // Groups inside the matched \"d\" route forward on out
      "OUT < e",
      'OUT DATA "d"',
      "OUT >",
      "MISSED < a",
      'OUT DATA "e"',
      "MISSED >",
    ]);
    c.tearDown?.();
  });
});

describe("KickRouter component", () => {
  /** Builds a KickRouter with 4 attached out connections. */
  const build = () => {
    const c = getKickRouter();
    const inSocket = noflo.internalSocket.createSocket();
    const indexSocket = noflo.internalSocket.createSocket();
    const prevSocket = noflo.internalSocket.createSocket();
    const nextSocket = noflo.internalSocket.createSocket();
    c.inPorts.in.attach(inSocket);
    c.inPorts.index.attach(indexSocket);
    c.inPorts.prev.attach(prevSocket);
    c.inPorts.next.attach(nextSocket);
    /** @type {import("@noflo/noflo").internalSocket.InternalSocket[]} */
    const outs = [];
    /** @type {string[]} */
    const received = [];
    for (let idx = 0; idx < 4; idx += 1) {
      const socket = noflo.internalSocket.createSocket();
      c.outPorts.out.attach(socket, idx);
      outs.push(socket);
      /**
       * @param {import("@noflo/noflo").internalSocket.InternalSocket} sock
       * @param {number} id
       */
      const track = (sock, id) => {
        sock.addEventListener(
          "ip",
          /** @param {CustomEvent} event */ (event) => {
            const ip = event.detail;
            if (ip.type === "openBracket") {
              received.push(`${id} < ${String(ip.data)}`);
              return;
            }
            if (ip.type === "closeBracket") {
              received.push(`${id} >`);
              return;
            }
            received.push(`${id} DATA ${JSON.stringify(ip.data)}`);
          },
        );
      };
      track(socket, idx);
    }
    return { c, inSocket, indexSocket, prevSocket, nextSocket, received };
  };

  it("releases a buffered stream to the next index", async () => {
    const { c, inSocket, nextSocket, received } = build();
    // Streams are buffered until a release signal arrives
    inSocket.post(new noflo.IP("openBracket", "foo"));
    inSocket.post(new noflo.IP("data", "a"));
    inSocket.post(new noflo.IP("closeBracket", "foo"));
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.deepEqual(received, []);
    nextSocket.post(new noflo.IP("data", null));
    inSocket.post(new noflo.IP("data", "b"));
    nextSocket.post(new noflo.IP("data", null));
    await new Promise((resolve) => setTimeout(resolve, 30));
    // The first next advances to index 1 and releases foo; the second
    // advances to index 2 and releases b
    assert.deepEqual(received, ["1 < foo", '1 DATA "a"', "1 >", '2 DATA "b"']);
    c.tearDown?.();
  });

  it("releases a buffered stream to the previous index", async () => {
    const { c, inSocket, prevSocket, received } = build();
    inSocket.post(new noflo.IP("openBracket", "foo"));
    inSocket.post(new noflo.IP("data", "a"));
    inSocket.post(new noflo.IP("closeBracket", "foo"));
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.deepEqual(received, []);
    prevSocket.post(new noflo.IP("data", null));
    inSocket.post(new noflo.IP("data", "b"));
    prevSocket.post(new noflo.IP("data", null));
    await new Promise((resolve) => setTimeout(resolve, 30));
    // prev wraps around to the last connection
    assert.deepEqual(received, ["3 < foo", '3 DATA "a"', "3 >", '2 DATA "b"']);
    c.tearDown?.();
  });

  it("releases buffered streams to the given indexes", async () => {
    const { c, inSocket, indexSocket, received } = build();
    inSocket.post(new noflo.IP("openBracket", "foo"));
    inSocket.post(new noflo.IP("data", "a"));
    inSocket.post(new noflo.IP("closeBracket", "foo"));
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.deepEqual(received, []);
    indexSocket.post(new noflo.IP("data", 0));
    inSocket.post(new noflo.IP("data", "b"));
    indexSocket.post(new noflo.IP("data", 2));
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.deepEqual(received, ["0 < foo", '0 DATA "a"', "0 >", '2 DATA "b"']);
    c.tearDown?.();
  });
});

describe("PacketRegexpRouter component", () => {
  it("routes matches by index", async () => {
    const c = getPacketRegexpRouter();
    const inSocket = noflo.internalSocket.createSocket();
    const routeSocket = noflo.internalSocket.createSocket();
    const out0 = noflo.internalSocket.createSocket();
    const out1 = noflo.internalSocket.createSocket();
    c.inPorts.in.attach(inSocket);
    c.inPorts.route.attach(routeSocket);
    c.outPorts.out.attach(out0, 0);
    c.outPorts.out.attach(out1, 1);
    /** @type {unknown[]} */
    const out0Data = [];
    /** @type {unknown[]} */
    const out1Data = [];
    out0.addEventListener(
      "ip",
      /** @param {CustomEvent} event */ (event) => {
        if (event.detail.type === "data") {
          out0Data.push(event.detail.data);
        }
      },
    );
    out1.addEventListener(
      "ip",
      /** @param {CustomEvent} event */ (event) => {
        if (event.detail.type === "data") {
          out1Data.push(event.detail.data);
        }
      },
    );
    routeSocket.post(new noflo.IP("data", ["^abc$", "^def$"]));
    inSocket.post(new noflo.IP("data", "abc"));
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.deepEqual(out0Data, ["abc"]);
    assert.deepEqual(out1Data, []);
    inSocket.post(new noflo.IP("data", "def"));
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.deepEqual(out1Data, ["def"]);
  });

  it("routes mismatches to missed", async () => {
    const c = getPacketRegexpRouter();
    const inSocket = noflo.internalSocket.createSocket();
    const routeSocket = noflo.internalSocket.createSocket();
    const out0 = noflo.internalSocket.createSocket();
    const missedSocket = noflo.internalSocket.createSocket();
    c.inPorts.in.attach(inSocket);
    c.inPorts.route.attach(routeSocket);
    c.outPorts.out.attach(out0, 0);
    c.outPorts.missed.attach(missedSocket);
    const missedIps = collect(missedSocket);
    routeSocket.post(new noflo.IP("data", ["^abc$"]));
    inSocket.post(new noflo.IP("data", "xyz"));
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.deepEqual(
      missedIps.filter((ip) => ip.type === "data").map((ip) => ip.data),
      ["xyz"],
    );
  });

  it("persists incoming groups around routed packets", async () => {
    const c = getPacketRegexpRouter();
    const inSocket = noflo.internalSocket.createSocket();
    const routeSocket = noflo.internalSocket.createSocket();
    const out0 = noflo.internalSocket.createSocket();
    c.inPorts.in.attach(inSocket);
    c.inPorts.route.attach(routeSocket);
    c.outPorts.out.attach(out0, 0);
    const outIps = collect(out0);
    routeSocket.post(new noflo.IP("data", ["^abc$"]));
    inSocket.post(new noflo.IP("openBracket", "grp"));
    inSocket.post(new noflo.IP("data", "abc"));
    inSocket.post(new noflo.IP("closeBracket", "grp"));
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.deepEqual(render(outIps), ["< grp", 'DATA "abc"', ">"]);
  });
});

describe("SplitInSequence component", () => {
  it("sends packets to connections in round-robin sequence", async () => {
    const c = getSplitInSequence();
    const inSocket = noflo.internalSocket.createSocket();
    c.inPorts.in.attach(inSocket);
    const outs = [];
    /** @type {unknown[]} */
    const received = [];
    for (let idx = 0; idx < 3; idx += 1) {
      const socket = noflo.internalSocket.createSocket();
      c.outPorts.out.attach(socket, idx);
      outs.push(socket);
      socket.addEventListener(
        "ip",
        /** @param {CustomEvent} event */ (event) => {
          if (event.detail.type === "data") {
            received.push(`${idx} ${event.detail.data}`);
          }
        },
      );
    }
    inSocket.post(new noflo.IP("data", "a"));
    inSocket.post(new noflo.IP("data", "b"));
    inSocket.post(new noflo.IP("data", "c"));
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.deepEqual(received, ["0 a", "1 b", "2 c"]);
  });
});

describe("ControlledSequence component", () => {
  it("switches output connection on each next bang", async () => {
    const c = getControlledSequence();
    const inSocket = noflo.internalSocket.createSocket();
    const nextSocket = noflo.internalSocket.createSocket();
    c.inPorts.in.attach(inSocket);
    c.inPorts.next.attach(nextSocket);
    /** @type {unknown[]} */
    const received = [];
    for (let idx = 0; idx < 3; idx += 1) {
      const socket = noflo.internalSocket.createSocket();
      c.outPorts.out.attach(socket, idx);
      const id = idx;
      socket.addEventListener(
        "ip",
        /** @param {CustomEvent} event */ (event) => {
          if (event.detail.type === "data") {
            received.push(`${id} ${event.detail.data}`);
          }
        },
      );
    }
    inSocket.post(new noflo.IP("data", "a"));
    await new Promise((resolve) => setTimeout(resolve, 20));
    nextSocket.post(new noflo.IP("data", null));
    inSocket.post(new noflo.IP("data", "b"));
    await new Promise((resolve) => setTimeout(resolve, 20));
    assert.deepEqual(received, ["0 a", "1 b"]);
  });
});
