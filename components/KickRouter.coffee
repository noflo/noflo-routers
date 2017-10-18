noflo = require 'noflo'

exports.getComponent = ->
  c = new noflo.Component
  c.description = 'Releases a stream to a specified index on prev/next/index'
  c.inPorts.add 'in',
    datatype: 'all'
  c.inPorts.add 'index',
    datatype: 'int'
  c.inPorts.add 'prev',
    datatype: 'bang'
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
    return unless input.hasStream 'in'
    unless c.current[input.scope]
      c.current[input.scope] = 0

    sendToIndex = ->
      stream = input.getStream 'in'
      attached = c.outPorts.out.listAttached()
      idx = attached[c.current[input.scope]]
      for packet in stream
        packet.index = idx
        output.send
          out: packet

    if input.hasData 'next'
      input.getData 'next'
      c.current[input.scope]++
      if c.current[input.scope] >= c.outPorts.out.listAttached().length
        c.current[input.scope] = 0
      do sendToIndex
      output.done()
      return
    if input.hasData 'prev'
      input.getData 'prev'
      c.current[input.scope]--
      if c.current[input.scope] < 0
        c.current[input.scope] = c.outPorts.out.listAttached().length - 1
      do sendToIndex
      output.done()
      return
    if input.hasData 'index'
      c.current[input.scope] = parseInt input.getData 'index'
      do sendToIndex
      output.done()
      return
