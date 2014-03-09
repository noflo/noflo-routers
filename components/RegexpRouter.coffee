noflo = require("noflo")
_ = require("underscore")

class RegexpRouter extends noflo.Component

  description: "Route IPs based on RegExp (top-level only). The position
  of the RegExp determines which port to forward to."

  constructor: ->
    @routes = []
    @sendToplevel = false

    @inPorts =
      in: new noflo.Port 'all'
      route: new noflo.ArrayPort 'string'
      reset: new noflo.Port 'bang'
      sendtoplevel: new noflo.Port 'boolean'
    @outPorts =
      out: new noflo.ArrayPort 'all'
      missed: new noflo.Port 'all'
      route: new noflo.Port 'string'

    @inPorts.reset.on "disconnect", =>
      @routes = []

    @inPorts.sendtoplevel.on 'data', (data) =>
      @sendTopLevel = String(data) is 'true'

    @inPorts.route.on "data", (regexp) =>
      if _.isString(regexp)
        @routes.push new RegExp regexp
      else
        throw new Error
          message: "Route must be a string"
          source: regexp

    @inPorts.in.on "connect", =>
      # Is there currently a match? If so, what's the route to forward to?
      @matchedRouteIndex = null
      # How deep are we in the group hierarchy?
      @level = 0

    @inPorts.in.on "begingroup", (group) =>
      index = @matchedRouteIndex

      # Only at root level
      if @level is 0
        for route, i in @routes
          if group.match(route)?
            @matchedRouteIndex = i
            if @outPorts.route.isAttached()
              @outPorts.route.send(group)
              @outPorts.route.disconnect()
            break

      else if index? and @outPorts.out.isAttached index
        @outPorts.out.beginGroup(group, index)
      else if @outPorts.missed.isAttached()
        @outPorts.missed.beginGroup(group)

      if @sendTopLevel and @level is 0
        if @matchedRouteIndex? and @outPorts.out.isAttached @matchedRouteIndex
          @outPorts.out.beginGroup(group, @matchedRouteIndex)
        else
          @outPorts.missed.beginGroup(group)


      # Go one level deeper
      @level++

    @inPorts.in.on "data", (data) =>
      if @matchedRouteIndex? and @outPorts.out.isAttached @matchedRouteIndex
        @outPorts.out.send(data, @matchedRouteIndex)
      else if @outPorts.missed.isAttached()
        @outPorts.missed.send(data)

    @inPorts.in.on "endgroup", (group) =>
      # Go one level up
      @level--

      # Remove matching if we're at root and it's currently matching
      if @level is 0 and @matchedRouteIndex?
        if @sendTopLevel
          if @matchedRouteIndex? and @outPorts.out.isAttached @matchedRouteIndex
            @outPorts.out.endGroup(@matchedRouteIndex)
          else if @outPorts.missed.isAttached()
            @outPorts.missed.endGroup()
        @matchedRouteIndex = null
        return

      if @matchedRouteIndex? and @outPorts.out.isAttached @matchedRouteIndex
        @outPorts.out.endGroup(@matchedRouteIndex)
      else if @outPorts.missed.isAttached()
        @outPorts.missed.endGroup()

    @inPorts.in.on "disconnect", =>
      @outPorts.out.disconnect()
      @outPorts.missed.disconnect() if @outPorts.missed.isAttached()

exports.getComponent = -> new RegexpRouter
