import { Component } from "@noflo/noflo";

/**
 * Re-evaluates whether there is a route match. There could only be one
 * match at most. Returns the match object.
 * @param {string[]} breadcrumbs
 * @param {RegExp[][]} routes
 * @returns {{ index: number|null, route: RegExp[]|null, level: number|null }}
 */
const matchRoute = (breadcrumbs, routes) => {
  for (let index = 0; index < routes.length; index += 1) {
    const route = routes[index];
    let matched = true;

    // Doesn't match if breadcrumbs is shorter than route's requirement
    if (route.length > breadcrumbs.length) {
      matched = false;
      continue;
    }

    // Doesn't match if any of the breadcrumbs doesn't match that of the route
    for (let step = 0; step < breadcrumbs.length; step += 1) {
      const group = breadcrumbs[step];
      if (!group.match(route[step])) {
        matched = false;
        break;
      }
    }

    // Match otherwise
    if (matched) {
      return {
        index,
        route,
        // We want the index of the breadcrumbs at which we have the match
        level: breadcrumbs.length - 1,
      };
    }
  }

  // An empty object for no match
  return { index: null, route: null, level: null };
};

/**
 * Routes IPs based on groups, which are matched and routed but not
 * removed when forwarding. The 1.x implementation's per-bracket
 * `missed` object flags are dead state — whenever the closeBracket
 * path reaches the no-match branch, the paired open bracket was also
 * unmatched, so the close forwards to missed as well.
 * @returns {import("@noflo/noflo").Component} The configured component
 */
export function getComponent() {
  const c = new Component({
    description:
      "routes IPs based on groups, which are matched and routed but not removed when forwarding",
    forwardBrackets: {},
    inPorts: {
      route: {
        datatype: "array",
        description: "Array of route segments",
      },
      routes: {
        datatype: "string",
        description: "Comma-separated list of route segments",
      },
      reset: {
        datatype: "bang",
        description: "Remove configured routes",
      },
      in: {
        datatype: "all",
        description: "Data to be routed by its groups",
        required: true,
      },
    },
    outPorts: {
      route: { datatype: "string" },
      out: { datatype: "all" },
      missed: { datatype: "all" },
      error: { datatype: "object" },
    },
  });

  /**
   * @typedef {Object} RouterScope
   * @property {RegExp[][]} routes
   * @property {string[]} breadcrumbs
   * @property {{ index: number|null, route: RegExp[]|null, level: number|null }} match
   */

  /** @type {Map<string, RouterScope>} */
  const scopes = new Map();
  c.tearDown = async () => {
    scopes.clear();
  };

  /**
   * @param {string|null} scope
   * @returns {RouterScope}
   */
  const prepareScope = (scope) => {
    const key = scope ?? "null";
    let state = scopes.get(key);
    if (!state) {
      state = {
        routes: [],
        breadcrumbs: [],
        match: { index: null, route: null, level: null },
      };
      scopes.set(key, state);
    }
    return state;
  };

  c.process((input, output) => {
    if (input.hasData("reset")) {
      input.getData("reset");
      scopes.delete(input.scope ?? "null");
      output.done();
      return;
    }
    if (input.hasData("route")) {
      const state = prepareScope(input.scope);
      const payload = input.getData("route");
      if (Array.isArray(payload)) {
        state.routes.push(payload.map((segment) => new RegExp(segment)));
        output.done();
        return;
      }
      if (typeof payload === "string") {
        state.routes.push([new RegExp(payload)]);
        output.done();
        return;
      }
      output.done(new Error("Route must be array of segments"));
      return;
    }
    if (input.hasData("routes")) {
      const state = prepareScope(input.scope);
      const payload = input.getData("routes");
      if (typeof payload !== "string") {
        output.done(new Error("Routes list must be a string"));
        return;
      }
      state.routes = payload
        .split(",")
        .map((route) => route.split(":").map((segment) => new RegExp(segment)));
      output.done();
      return;
    }
    if (!input.has("in")) {
      return;
    }
    const state = prepareScope(input.scope);
    const packet = /** @type {import("@noflo/noflo").IP} */ (input.get("in"));
    switch (packet.type) {
      case "openBracket": {
        // Update where we are
        state.breadcrumbs.push(packet.data);

        // Forward group if we are in a match
        if (
          state.match.level !== null &&
          state.match.level < state.breadcrumbs.length
        ) {
          output.sendDone({ out: packet });
          return;
        }

        // Try to match
        state.match = matchRoute(state.breadcrumbs, state.routes);

        // There is a match. Notify downstream if connected
        if (state.match.route !== null) {
          output.sendDone({ route: state.match.route });
          return;
        }

        // Send to missed otherwise
        output.sendDone({ missed: packet });
        return;
      }
      case "closeBracket": {
        // Update where we are
        state.breadcrumbs.pop();

        // Forward group if we are in a match
        if (
          state.match.level !== null &&
          state.match.level < state.breadcrumbs.length
        ) {
          output.sendDone({ out: packet });
          return;
        }

        // *END* a match once we're at the end of a match
        if (state.match.level === state.breadcrumbs.length) {
          state.match = { index: null, route: null, level: null };
          output.done();
          return;
        }

        // Send to missed otherwise
        output.sendDone({ missed: packet });
        return;
      }
      default: {
        if (state.match.route !== null) {
          output.sendDone({ out: packet });
          return;
        }

        output.sendDone({ missed: packet });
      }
    }
  });

  return c;
}
