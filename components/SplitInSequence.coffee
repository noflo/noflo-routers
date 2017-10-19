noflo = require 'noflo'

exports.getComponent = ->
  c = new noflo.Component
  c.description = 'Send each packet to one outport connection in sequence'
  c.inPorts.add 'in',
    datatype: 'all'
  c.outPorts.add 'out',
    datatype: 'all'
    addressable: true
  c.current = 0
  c.tearDown = (callback) ->
    c.current = 0
    do callback
  c.process (input, output) ->
    return unless input.hasData 'in'
    packet = new noflo.IP 'data', input.getData 'in'
    attached = c.outPorts.out.listAttached()
    packet.index = attached[c.current]
    output.send
      out: packet
    c.current++
    if c.current >= c.outPorts.out.listAttached().length
      c.current = 0
    output.done()
    return
