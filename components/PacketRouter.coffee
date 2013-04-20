noflo = require("noflo")
inherit = require("multiple-inheritance")

class PacketRouter extends noflo.Component

  description: "routes IPs based on position in an incoming IP stream"

  constructor: ->
    @inPorts =
      in: new noflo.Port
    @outPorts =
      out: new noflo.ArrayPort
      missed: new noflo.Port

    @inPorts.in.on "connect", =>
      # How deep are we in the group hierarchy?
      @level = 0
      # How many group/data IPs at the root level have been passed?
      @count = 0
      # How many out ports are there?
      @outPortCount = @outPorts.out.sockets.length

    @inPorts.in.on "begingroup", (group) =>
      @route("beginGroup", group)

      # Go one level deeper
      @level++

    @inPorts.in.on "data", (data) =>
      @route("send", data)

      # Only the positions of the top-level packets determine where to
      # route the IPs.
      if @level is 0
        @count++

    @inPorts.in.on "endgroup", (group) =>
      @route("endGroup", group)

      # Go one level up
      @level--

      # Only the positions of the top-level packets determine where to
      # route the IPs.
      if @level is 0
        @count++

    @inPorts.in.on "disconnect", =>
      @outPorts.out.disconnect()
      @outPorts.missed.disconnect()

  # Route IPs until it has exhausted outgoing sockets
  route: (operation, data) ->
    port = if @count < @outPortCount then @outPorts.out else @outPorts.missed

    if operation is "endGroup"
      port[operation](@count)
    else
      port[operation](data, @count)
 
exports.getComponent = -> new PacketRouter
