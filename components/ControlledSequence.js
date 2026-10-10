import { Component } from "@noflo/noflo";

/**
 * Switches output to the next out connection every time a bang arrives
 * on `next`. Per scope.
 * @returns {import("@noflo/noflo").Component} The configured component
 */
export function getComponent() {
  const c = new Component({
    description: 'Switch output to new connection every time "next" is sent',
    forwardBrackets: {},
    inPorts: {
      in: { datatype: "all", required: true },
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
    const key = input.scope ?? "null";
    if (input.hasData("next")) {
      input.getData("next");
      if (!currents.has(key)) {
        currents.set(key, 0);
      }
      currents.set(key, (currents.get(key) ?? 0) + 1);
      if ((currents.get(key) ?? 0) >= c.outPorts.out.listAttached().length) {
        currents.set(key, 0);
      }
      output.done();
      return;
    }
    if (!input.has("in")) {
      return;
    }
    if (!currents.has(key)) {
      currents.set(key, 0);
    }
    const packet = /** @type {import("@noflo/noflo").IP} */ (input.get("in"));
    const attached = c.outPorts.out.listAttached();
    packet.index = attached[currents.get(key) ?? 0];
    output.sendDone({ out: packet });
  });

  return c;
}
