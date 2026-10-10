import { Component } from "@noflo/noflo";

/**
 * Routes IPs based on position in an incoming IP stream: each
 * top-level substream goes to the next attached out connection.
 * Unnamed surrounding brackets are stripped.
 * @returns {import("@noflo/noflo").Component} The configured component
 */
export function getComponent() {
  const c = new Component({
    description: "Routes IPs based on position in an incoming IP stream",
    forwardBrackets: {},
    inPorts: {
      in: { datatype: "all", addressable: true, required: true },
    },
    outPorts: {
      out: {
        datatype: "all",
        addressable: true,
      },
      missed: { datatype: "all" },
      error: { datatype: "object" },
    },
  });

  c.process((input, output) => {
    const indexesWithStream = /** @type {number[]} */ (
      input.attached("in")
    ).filter((idx) => input.hasStream(["in", idx]));
    if (!indexesWithStream.length) {
      return;
    }
    for (const idx of indexesWithStream) {
      const stream = /** @type {import("@noflo/noflo").IP[]} */ (
        input.getStream(["in", idx])
      );
      if (stream[0].type === "openBracket" && stream[0].data === null) {
        // Remove the surrounding brackets if they're unnamed
        stream.shift();
        stream.pop();
      }
      let position = 0;
      /** @type {unknown[]} */
      const brackets = [];
      let hadData = false;
      for (const packet of stream) {
        if (packet.type === "openBracket") {
          if (hadData && !brackets.length) {
            // Start of a new substream
            position += 1;
          }
          brackets.push(packet.data);
        }
        if (packet.type === "closeBracket") {
          brackets.pop();
        }

        const attached = c.outPorts.out.listAttached();
        if (!attached.includes(position)) {
          // The target connection is not attached; the source
          // connection index must not leak into the non-addressable
          // missed port
          packet.index = null;
          output.send({ missed: packet });
          continue;
        }

        packet.index = position;
        output.send({ out: packet });

        if (packet.type === "data") {
          if (hadData && brackets.length) {
            // Was already advanced by openBracket
            continue;
          }
          position += 1;
          hadData = true;
        }
      }
    }
    output.done();
  });

  return c;
}
