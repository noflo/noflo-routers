import { Component, IP } from "@noflo/noflo";

/**
 * Routes string IPs by RegExp matches: the position of the matching
 * RegExp in the `route` array determines the target out connection.
 * @returns {import("@noflo/noflo").Component} The configured component
 */
export function getComponent() {
  const c = new Component({
    description:
      "Route IPs based on RegExp match on the IP content (strings only). The position of the RegExp determines which port to forward to.",
    forwardBrackets: { in: ["out", "missed"] },
    inPorts: {
      in: { datatype: "string", required: true },
      route: { datatype: "array", control: true, required: true },
    },
    outPorts: {
      out: {
        datatype: "string",
        addressable: true,
      },
      missed: { datatype: "all" },
      error: { datatype: "object" },
    },
  });

  c.process((input, output) => {
    if (!input.hasData("in", "route")) {
      return;
    }
    const routes = input.getData("route");
    if (!Array.isArray(routes)) {
      output.done(new Error("Route must be an array"));
      return;
    }
    /** @type {RegExp[]} */
    const regexps = [];
    /** @type {Error|undefined} */
    let errored;
    for (const route of routes) {
      if (typeof route === "string") {
        regexps.push(new RegExp(route));
        continue;
      }
      if (route instanceof RegExp) {
        regexps.push(route);
        continue;
      }
      errored = new Error("Route array can only contain strings or RegExps");
    }
    if (errored) {
      output.done(errored);
      return;
    }

    const data = input.getData("in");
    if (typeof data !== "string") {
      output.done(new Error("PacketRegexpRouter can only route strings"));
      return;
    }
    /** @type {number[]} */
    const matchedIndexes = [];
    for (let idx = 0; idx < regexps.length; idx += 1) {
      const regexp = regexps[idx];
      if (data.match(regexp)) {
        matchedIndexes.push(idx);
      }
    }
    if (!matchedIndexes.length) {
      output.sendDone({ missed: data });
      return;
    }
    for (const idx of matchedIndexes) {
      const ip = new IP("data", data);
      ip.index = idx;
      output.send({ out: ip });
    }
    output.done();
  });

  return c;
}
