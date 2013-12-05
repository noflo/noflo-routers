noflo = require 'noflo'

class ControlledSequence extends noflo.Component
  constructor: ->
    @current = 0
    @inPorts =
      in: new noflo.Port 'all'
      next: new noflo.Port 'bang'
    @outPorts =
      out: new noflo.ArrayPort 'all'

    @inPorts.in.on 'begingroup', (group) =>
      @outPorts.out.beginGroup group, @current
    @inPorts.in.on 'data', (data) =>
      @outPorts.out.send data, @current
    @inPorts.in.on 'endgroup', =>
      @outPorts.out.endGroup @current
    @inPorts.in.on 'disconnect', =>
      @outPorts.out.disconnect @current

    @inPorts.next.on 'data', =>
      @outPorts.out.disconnect @current
      if @current < @outPorts.out.sockets.length - 1
        @current++
        return
      @current = 0

exports.getComponent = -> new ControlledSequence
