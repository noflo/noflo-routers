import { Component } from "@noflo/noflo";

/**
 * Releases a stream to the configured out connection, switched by
 * prev/next/index controls. Per scope.
 * @returns {import("@noflo/noflo").Component} The configured component
 */
export function getComponent() {
  const c = new Component({
    description: "Releases a stream to a specified index on prev/next/index",
    forwardBrackets: {},
    inPorts: {
      in: { datatype: "all", required: true },
      index: { datatype: "int" },
      prev: { datatype: "bang" },
      next: { datatype: "bang" },
    },
    outPorts: {
      out: {
        datatype: "all",
        addressable: true,
      },
    },
  });

  /** @type {Map<string, number>} */
  const currents = new Map();
  c.tearDown = async () => {
    currents.clear();
  };

  c.process((input, output) => {
    if (!input.hasStream("in")) {
      return;
    }
    const key = input.scope ?? "null";
    if (!currents.has(key)) {
      currents.set(key, 0);
    }

    const sendToIndex = () => {
      const stream = /** @type {import("@noflo/noflo").IP[]} */ (
        input.getStream("in")
      );
      const attached = c.outPorts.out.listAttached();
      const idx = attached[currents.get(key) ?? 0];
      for (const packet of stream) {
        packet.index = idx;
        output.send({ out: packet });
      }
    };

    if (input.hasData("next")) {
      input.getData("next");
      currents.set(key, (currents.get(key) ?? 0) + 1);
      if ((currents.get(key) ?? 0) >= c.outPorts.out.listAttached().length) {
        currents.set(key, 0);
      }
      sendToIndex();
      output.done();
      return;
    }
    if (input.hasData("prev")) {
      input.getData("prev");
      currents.set(key, (currents.get(key) ?? 0) - 1);
      if ((currents.get(key) ?? 0) < 0) {
        currents.set(key, c.outPorts.out.listAttached().length - 1);
      }
      sendToIndex();
      output.done();
      return;
    }
    if (input.hasData("index")) {
      currents.set(key, Number.parseInt(input.getData("index"), 10));
      sendToIndex();
      output.done();
    }
  });

  return c;
}
