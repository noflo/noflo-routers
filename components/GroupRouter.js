const noflo = require('noflo');

// Re-evaluate whether there is a route match. There could only be one match at
// most. Returns the match object.
function matchRoute(breadcrumbs, routes) {
  for (let index = 0; index < routes.length; index += 1) {
    const route = routes[index];
    let matched = true;

    // Doesn't match if breadcrumbs is shorter than route's requirement
    if (route.length > breadcrumbs.length) {
      matched = false;
      // eslint-disable-next-line no-continue
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
  return {};
}

exports.getComponent = () => {
  const component = new noflo.Component();
  component.description = 'routes IPs based on groups, which are matched and routed but not removed when forwarding';
  component.inPorts.add('route', {
    datatype: 'array',
    description: 'Array of route segments',
  });
  component.inPorts.add('routes', {
    datatype: 'string',
    description: 'Comma-separated list of route segments',
  });
  component.inPorts.add('reset', {
    datatype: 'bang',
    description: 'Remove configured routes',
  });
  component.inPorts.add('in', {
    datatype: 'all',
    description: 'Data to be routed by its groups',
  });
  component.outPorts.add('out', {
    datatype: 'all',
    addressable: true,
  });
  component.outPorts.add('route',
    { datatype: 'string' });
  component.outPorts.add('missed',
    { datatype: 'all' });
  component.outPorts.add('error',
    { datatype: 'object' });

  component.scopes = {};
  const prepareScope = function (scope) {
    if (component.scopes[scope]) {
      return component.scopes[scope];
    }
    component.scopes[scope] = {
      // Registered routes
      routes: [],
      // Where we are
      breadcrumbs: [],
      // Object describing the match
      match: {
        // The matching route's index in the routes array
        index: null,
        // A reference to the matching route for convenience
        route: null,
        // Where the match occurred (the "level" within breadcrumbs)
        level: null,
      },
    };
    return component.scopes[scope];
  };
  component.tearDown = function (callback) {
    component.scopes = {};
    return callback();
  };
  component.forwardBrackets = {};
  return component.process((input, output) => {
    let payload; let
      scope;
    if (input.hasData('reset')) {
      input.getData('reset');
      delete component.scopes[input.scope];
      output.done();
      return;
    }
    if (input.hasData('route')) {
      scope = prepareScope(input.scope);
      payload = input.getData('route');
      if (Array.isArray(payload)) {
        scope.routes.push(payload.map((segment) => new RegExp(segment)));
        output.done();
        return;
      }
      if (typeof payload === 'string') {
        scope.routes.push([new RegExp(payload)]);
        output.done();
        return;
      }
      output.done(new Error('Route must be array of segments'));
      return;
    }
    if (input.hasData('routes')) {
      scope = prepareScope(input.scope);
      payload = input.getData('routes');
      if (typeof payload !== 'string') {
        output.done(new Error('Routes list must be a string'));
      }
      scope.routes = payload.split(',').map((route) => route.split(':').map((segment) => new RegExp(segment)));
      output.done();
      return;
    }
    if (!input.has('in')) { return; }
    scope = prepareScope(input.scope);
    const packet = input.get('in');
    switch (packet.type) {
      case 'openBracket': {
        // Update where we are
        const bracketResult = { group: packet.data };
        scope.breadcrumbs.push(bracketResult);

        // Forward group if we are in a match
        if ((scope.match.level != null) && (scope.match.level < scope.breadcrumbs.length)) {
          packet.index = scope.match.index;
          output.sendDone({ out: packet });
          return;
        }

        // Try to match
        scope.match = matchRoute(
          scope.breadcrumbs.map((breadcrumb) => breadcrumb.group),
          scope.routes,
        );

        // There is a match. Notify downstream if connected
        if (scope.match.route != null) {
          output.sendDone({ route: scope.match.route });
          return;
        }

        // Send to missed otherwise
        bracketResult.missed = true;
        output.sendDone({ missed: packet });
        return;
      }
      case 'closeBracket': {
        // Update where we are
        const bracketResult = scope.breadcrumbs.pop();

        // Forward group if we are in a match
        if (scope.match.level < scope.breadcrumbs.length) {
          packet.index = scope.match.index;
          output.sendDone({ out: packet });
          return;
        }

        // *END* a match once we're at the end of a match
        if (scope.match.level === scope.breadcrumbs.length) {
          scope.match = {};
          output.done();
          return;
        }

        // Send to missed if there is no match
        if (!bracketResult.missed) {
          output.done();
          return;
        }
        output.sendDone({ missed: packet });
        return;
      }
      default: {
        if (scope.match.route != null) {
          packet.index = scope.match.index;
          output.sendDone({ out: packet });
          return;
        }

        output.sendDone({ missed: packet });
      }
    }
  });
};
