noflo = require "noflo"
_ = require "underscore"

exports.getComponent = ->
  # Registered routes
  routes = []
  # Where we are
  breadcrumbs = []
  # Object describing the match
  match =
    # The matching route's index in the routes array
    index: null
    # A reference to the matching route for convenience
    route: null
    # Where the match occurred (the "level" within breadcrumbs)
    level: null

  component = new noflo.Component
    outPorts:
      out: new noflo.OutPort
        addressable: true
      route: new noflo.OutPort
      missed: new noflo.OutPort
    inPorts: new noflo.InPorts

  component.description = "routes IPs based on groups, which are matched and
  routed but not removed when forwarding"


  component.inPorts.add 'route', (event, payload) ->
    switch event
      when 'data'
        if _.isArray payload
          routes.push _.map payload, (segment) -> new RegExp segment
        else if not _.isObject payload
          routes.push [new RegExp payload]
        else
          throw new Error
            message: "Route must be array of segments"
            source: segments

  component.inPorts.add 'reset', (event, payload) ->
    switch event
      when 'disconnect'
        routes = []

  component.inPorts.add 'in', (event, payload) ->
    switch event
      when 'begingroup'
        # Update where we are
        breadcrumbs.push payload

        # Forward group if we are in a match
        if match.level? and match.level < breadcrumbs.length
          component.outPorts.out.beginGroup payload, match.index
          return

        # Try to match
        match = matchRoute breadcrumbs, routes

        # There is a match. Notify downstream if connected
        if match.route?
          component.outPorts.route.send match.route
          component.outPorts.route.disconnect()
          return

        # Send to missed otherwise
        component.outPorts.missed.beginGroup payload

      when 'endgroup'
        # Update where we are
        breadcrumbs.pop()

        # Forward group if we are in a match
        if match.level < breadcrumbs.length
          component.outPorts.out.endGroup match.index
          return

        # *END* a match once we're at the end of a match
        if match.level is breadcrumbs.length
          component.outPorts.out.disconnect match.index
          match = {}
          return

        # Send to missed if there is no match
        component.outPorts.missed.endGroup()

      when 'disconnect'
        component.outPorts.missed.disconnect()

      when 'data'
        if match.route?
          component.outPorts.out.send payload, match.index
        else
          component.outPorts.missed.send payload

  # Backward compatibility
  # TODO: should be removed in future releases of noflo
  component.inPorts.add 'routes', (event, payload) ->
    switch event
      when 'data'
        if typeof payload is "string"
          routes = _.map payload.split(','), (route) ->
            _.map route.split(':'), (segment) ->
              new RegExp segment

  # Return created component
  return component


# Re-evaluate whether there is a route match. There could only be one match at
# most. Returns the match object.
matchRoute = (breadcrumbs, routes) ->
  for route, index in routes
    matched = true

    # Doesn't match if breadcrumbs is shorter than route's requirement
    if route.length > breadcrumbs.length
      matched = false
      continue

    # Doesn't match if any of the breadcrumbs doesn't match that of the route
    for group, step in breadcrumbs
      unless group.match route[step]
        matched = false
        break

    # Match otherwise
    if matched
      return {
        index: index
        route: route
        # We want the index of the breadcrumbs at which we have the match
        level: breadcrumbs.length - 1
      }

  # An empty object for no match
  return {}
