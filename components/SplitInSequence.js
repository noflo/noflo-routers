import { Component, IP } from "@noflo/noflo";

/**
 * Sends each packet to one out connection in round-robin sequence.
 * @returns {import("@noflo/noflo").Component} The configured component
 */
export function getComponent() {
  const c = new Component({
    description: "Send each packet to one outport connection in sequence",
    inPorts: {
      in: { datatype: "all", required: true },
    },
    outPorts: {
      out: {
        datatype: "all",
        addressable: true,
      },
    },
  });

  let current = 0;
  c.tearDown = async () => {
    current = 0;
  };

  c.process((input, output) => {
    if (!input.hasData("in")) {
      return;
    }
    const packet = new IP("data", input.getData("in"));
    const attached = c.outPorts.out.listAttached();
    packet.index = attached[current];
    output.send({ out: packet });
    current += 1;
    if (current >= c.outPorts.out.listAttached().length) {
      current = 0;
    }
    output.done();
  });

  return c;
}
