import * as noflo from "@noflo/noflo";

/**
 * Waits for the next IP on a socket matching the predicate.
 * @param {import("@noflo/noflo").internalSocket.InternalSocket} socket
 * @param {(ip: import("@noflo/noflo").IP) => boolean} predicate
 * @returns {Promise<import("@noflo/noflo").IP>}
 */
export const waitUntil = (socket, predicate) =>
  new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      cleanup();
      reject(new Error("Timed out waiting for IP"));
    }, 2000);
    /** @param {CustomEvent} event */
    const listener = (event) => {
      const ip = event.detail;
      if (predicate(ip)) {
        cleanup();
        resolve(ip);
      }
    };
    const cleanup = () => {
      clearTimeout(timer);
      socket.removeEventListener("ip", listener);
    };
    socket.addEventListener("ip", listener);
  });

/**
 * Collects every IP arriving on the socket. Attach before posting —
 * activations can complete synchronously inside the completing post.
 * @param {import("@noflo/noflo").internalSocket.InternalSocket} socket
 * @returns {import("@noflo/noflo").IP[]}
 */
export const collect = (socket) => {
  /** @type {import("@noflo/noflo").IP[]} */
  const ips = [];
  socket.addEventListener(
    "ip",
    /** @param {CustomEvent} event */ (event) => {
      ips.push(event.detail);
    },
  );
  return ips;
};

/**
 * Renders an IP stream in the 1.x spec notation: `< group`,
 * `DATA <json>` and `>`. Makes bracket-structure expectations readable.
 * @param {import("@noflo/noflo").IP[]} ips
 * @returns {string[]}
 */
export const render = (ips) =>
  ips.map((ip) => {
    if (ip.type === "openBracket") {
      return `< ${String(ip.data)}`;
    }
    if (ip.type === "closeBracket") {
      return ">";
    }
    if (ip.type === "data") {
      return `DATA ${JSON.stringify(ip.data)}`;
    }
    return `${ip.type}`;
  });

/**
 * Posts a grouped stream to a socket, mirroring the 1.x spec helpers.
 * @param {import("@noflo/noflo").internalSocket.InternalSocket} socket
 * @param {unknown[]} groups Leading group names, null for unnamed
 * @param {unknown[]} data Data values to send inside the groups
 */
export const sendGrouped = (socket, groups, data) => {
  for (const group of groups) {
    socket.post(new noflo.IP("openBracket", group));
  }
  for (const value of data) {
    socket.post(new noflo.IP("data", value));
  }
  for (let i = 0; i < groups.length; i += 1) {
    socket.post(new noflo.IP("closeBracket", groups[groups.length - 1 - i]));
  }
};

/**
 * Waits until the collected stream satisfies the predicate.
 * @param {import("@noflo/noflo").IP[]} ips
 * @param {(ips: import("@noflo/noflo").IP[]) => boolean} predicate
 * @returns {Promise<void>}
 */
export const waitStream = (ips, predicate) =>
  new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      clearInterval(interval);
      reject(new Error("Timed out waiting for stream"));
    }, 2000);
    const interval = setInterval(() => {
      if (predicate(ips)) {
        clearTimeout(timer);
        clearInterval(interval);
        resolve();
      }
    }, 10);
  });
