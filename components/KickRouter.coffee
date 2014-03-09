noflo = require 'noflo'

class KickRouter extends noflo.Component

  description: "Holds an IP and send it to a specified port or previous/next"

  constructor: ->
    @data = null
    @current = 0

    @inPorts =
      in: new noflo.Port 'all'
      index: new noflo.Port 'int'
      prev: new noflo.Port 'bang'
      next: new noflo.Port 'bang'
    @outPorts =
      out: new noflo.ArrayPort 'all'

    @inPorts.in.on 'data', (data) =>
      @data = data

    @inPorts.index.on 'data', (index) =>
      @sendToIndex @data, index

    @inPorts.prev.on 'data', =>
      @outPorts.out.disconnect @current
      if @current > 0
        @current--
      else
        @current = @outPorts.out.sockets.length - 1
      @sendToIndex @data, @current

    @inPorts.next.on 'data', =>
      @outPorts.out.disconnect @current
      if @current < @outPorts.out.sockets.length - 1
        @current++
      else
        @current = 0
      @sendToIndex @data, @current

  sendToIndex: (data, index) =>
    if @outPorts.out.isAttached(index)
      @current = index
      @outPorts.out.send data, index


exports.getComponent = -> new KickRouter
