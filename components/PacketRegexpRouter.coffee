noflo = require("noflo")

exports.getComponent = ->
  c = new noflo.Component
  c.description = "Route IPs based on RegExp match on the IP content (strings
    only). The position of the RegExp determines which port to forward to."
  c.inPorts.add 'in',
    datatype: 'string'
  c.inPorts.add 'route',
    datatype: 'array'
    control: true
  c.outPorts.add 'out',
    datatype: 'string'
    addressable: true
  c.outPorts.add 'missed',
    datatype: 'all'
  c.outPorts.add 'error',
    datatype: 'object'
  c.forwardBrackets =
    in: ['out', 'missed']
  c.process (input, output) ->
    return unless input.hasData 'in', 'route'
    routes = input.getData 'route'
    unless Array.isArray routes
      output.done new Error 'Route must be an array'
      return
    regexps = []
    for route in routes
      if typeof route is 'string'
        regexps.push new RegExp route
        continue
      if route instanceof RegExp
        regexps.push route
        continue
      output.done new Error 'Route array can only contain strings or RegExps'
      return

    data = input.getData 'in'
    unless typeof data is 'string'
      output.done new Error 'PacketRegexpRouter can only route strings'
      return
    matchedIndexes = []
    for regexp, idx in regexps
      matchedIndexes.push idx if data.match regexp
    unless matchedIndexes.length
      output.sendDone
        missed: data
      return
    for idx in matchedIndexes
      output.send
        out: new noflo.IP 'data', data,
          index: idx
    output.done()
    return
