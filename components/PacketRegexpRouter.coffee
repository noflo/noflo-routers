noflo = require("noflo")
_ = require("underscore")


class PacketRegexpRouter extends noflo.Component

  description: "Route IPs based on RegExp match on the IP content (strings
    only). The position of the RegExp determines which port to forward to."

  constructor: ->
    @routes = []
    @groups = []

    @inPorts =
      in: new noflo.Port 'all'
      route: new noflo.Port 'array'
    @outPorts =
      out: new noflo.ArrayPort 'all'
      missed: new noflo.Port 'all'

    @inPorts.route.on "data", (regexps) =>
      unless _.isArray regexps
        throw new TypeError
          message: "Route must be an array"
          source: regexp

      for regexp in regexps
        if _.isString(regexp)
          @routes.push new RegExp regexp
        else
          throw new TypeError
            message: "Route array can only contain strings"
            source: regexp

    @inPorts.in.on "begingroup", (group) =>
      @groups.push group

    @inPorts.in.on "data", (data) =>
      matchedIndexes = @getIndexesFor data

      for idx in matchedIndexes
        @outPorts.out.beginGroup group, idx for group in @groups
        @outPorts.out.send data, idx
        @outPorts.out.endGroup idx for group in @groups

      unless matchedIndexes.length
        @outPorts.missed.beginGroup group for group in @groups
        @outPorts.missed.send data
        @outPorts.missed.endGroup() for group in @groups

    @inPorts.in.on "endgroup", (group) =>
      @groups.pop()

    @inPorts.in.on "disconnect", =>
      @outPorts.out.disconnect idx for sock, idx in @outPorts.out.sockets
      @outPorts.missed.disconnect() if @outPorts.missed.isAttached()

  getIndexesFor: (data) ->
    matchedIndexes = []

    for route, idx in @routes
      matchedIndexes.push idx if data.match route

    return matchedIndexes


exports.getComponent = -> new PacketRegexpRouter
