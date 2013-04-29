Socket = require("../node_modules/noflo/src/lib/InternalSocket")

setup = (component, inNames=[], outNames=[], type = "component") ->
  c = require("../#{type}s/#{component}").getComponent()
  inPorts = []
  outPorts = []

  for name in inNames
    port = Socket.createSocket()
    c.inPorts[name].attach(port)
    inPorts.push(port)

  for name in outNames
    port = Socket.createSocket()
    c.outPorts[name].attach(port)
    outPorts.push(port)

  [c, inPorts, outPorts]

exports["route incoming IPs based on RegExp (only the top-level)"] = (test) ->
  [c, [routesIns, ins], [outA, outB, missedOut]] = setup("RegexpRouter", ["route", "in"], ["out", "out", "missed"])

  outA.on "begingroup", (group) ->
    test.equal(group, "group")
  outA.on "data", (data) ->
    test.equal(data, "abc")
  outB.on "data", (data) ->
    test.equal(data, "xyz")
  missedOut.on "data", (data) ->
    test.equal(data, "missed")
  missedOut.on "disconnect", ->
    test.done()

  routesIns.connect()
  routesIns.send("c$")
  routesIns.send("^x")
  routesIns.disconnect()

  ins.connect()
  ins.beginGroup("abc")
  ins.beginGroup("group")
  ins.send("abc")
  ins.endGroup("group")
  ins.endGroup("abc")
  ins.beginGroup("cba")
  ins.send("missed")
  ins.endGroup("cba")
  ins.beginGroup("xyz")
  ins.send("xyz")
  ins.endGroup("xyz")
  ins.disconnect()

exports["reset the routes"] = (test) ->
  [c, [resetIns, routesIns, ins], [outA, outB, missedOut]] = setup("RegexpRouter", ["reset", "route", "in"], ["out", "out", "missed"])

  outA.on "data", (data) ->
    test.equal(data, "abc")
  missedOut.on "disconnect", ->
    test.done()

  routesIns.connect()
  routesIns.send("cba")
  routesIns.disconnect()

  resetIns.connect()
  resetIns.disconnect()

  routesIns.connect()
  routesIns.send("abc")
  routesIns.disconnect()

  ins.connect()
  ins.beginGroup("abc")
  ins.send("abc")
  ins.endGroup("abc")
  ins.beginGroup("cba")
  ins.send("missed")
  ins.endGroup("cba")
  ins.disconnect()
