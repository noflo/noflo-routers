noflo = require 'noflo'

exports.getComponent = ->
  c = new noflo.Component
  c.description = 'Switch output to new connection every time "next" is sent'
  c.inPorts.add 'in',
    datatype: 'all'
  c.inPorts.add 'next',
    datatype: 'bang'
  c.outPorts.add 'out',
    datatype: 'all'
    addressable: true
  c.current = {}
  c.tearDown = (callback) ->
    c.current = {}
    do callback
  c.forwardBrackets = {}
  c.process (input, output) ->
    if input.hasData 'next'
      input.getData 'next'
      unless c.current[input.scope]
        c.current[input.scope] = 0
      c.current[input.scope]++
      if c.current[input.scope] >= c.outPorts.out.listAttached().length
        c.current[input.scope] = 0
      output.done()
      return
    return unless input.has 'in'
    unless c.current[input.scope]
      c.current[input.scope] = 0
    packet = input.get 'in'
    attached = c.outPorts.out.listAttached()
    packet.index = attached[c.current[input.scope]]
    output.sendDone
      out: packet
