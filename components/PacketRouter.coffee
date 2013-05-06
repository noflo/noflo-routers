noflo = require("noflo")

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
      # Simply connect unmatched ports without sending them anything
      if @outPortCount > @count
        for i in [@count...@outPortCount]
          @outPorts.out.connect i

      @outPorts.out.disconnect()
      @outPorts.missed.disconnect() if @outPorts.missed.isAttached()

  # Route IPs until it has exhausted outgoing sockets
  route: (operation, data) ->
    portName = if @count < @outPortCount then "out" else "missed"
    port = @outPorts[portName]

    if portName is "out" or port.isAttached()
      if operation is "endGroup"
        port[operation](@count)
      else
        port[operation](data, @count)

exports.getComponent = -> new PacketRouter
