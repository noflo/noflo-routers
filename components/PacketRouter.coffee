noflo = require("noflo")

exports.getComponent = ->
  c = new noflo.Component
  c.description = "Routes IPs based on position in an incoming IP stream"
  c.inPorts.add 'in',
    datatype: 'all'
    addressable: true
  c.outPorts.add 'out',
    datatype: 'all'
    addressable: true
  c.outPorts.add 'missed',
    datatype: 'all'
  c.outPorts.add 'error'
  c.forwardBrackets = {}
  c.process (input, output) ->
    indexesWithStreams = input.attached('in').filter (idx) ->
      input.hasStream ['in', idx]
    return unless indexesWithStreams.length
    indexesWithStreams.forEach (idx) ->
      stream = input.getStream ['in', idx]
      if stream[0].type is 'openBracket' and stream[0].data is null
        # Remove the surrounding brackets if they're unnamed
        before = stream.shift()
        after = stream.pop()
      position = 0
      brackets = []
      hadData = false
      for packet in stream
        if packet.type is 'openBracket'
          if hadData and not brackets.length
            # Start of a new substream
            position++
          brackets.push packet.data
        if packet.type is 'closeBracket'
          brackets.pop()

        attached = c.outPorts.out.listAttached()
        if attached.indexOf(position) is -1
          output.send
            missed: packet
          continue

        packet.index = position
        output.send
          out: packet

        if packet.type is 'data'
          if hadData and brackets.length
            # Was already advanced by openBracket
            continue
          position++
          hadData = true
    output.done()
    return
