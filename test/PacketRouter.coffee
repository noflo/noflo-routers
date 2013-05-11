Socket = require("../node_modules/noflo/src/lib/InternalSocket")

setup = (component, inNames=[], outNames=[]) ->
  c = require("../components/#{component}").getComponent()
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

exports["routes incoming IPs based on IP stream position"] = (test) ->
  [c, [ins], [outA, outB, missedOut]] = setup("PacketRouter", ["in"], ["out", "out", "missed"])

  expectedMissed = ["c", "d"]

  outA.on "data", (data) ->
    test.equal(data, "a")

  outB.on "data", (data) ->
    test.equal(data, "b")

  missedOut.on "data", (data) ->
    test.equal(data, expectedMissed.shift())
  missedOut.on "disconnect", ->
    test.done()

  ins.connect()
  ins.send("a")
  ins.send("b")
  ins.send("c")
  ins.disconnect()

exports["router still connects to unmatched ports"] = (test) ->
  [c, [ins], [outA, outB, outC]] = setup("PacketRouter", ["in"], ["out", "out", "out"])

  test.expect 3

  outA.on "data", (data) ->
    test.equal data, 1
  outB.on "data", (data) ->
    test.equal data, 2
  outC.on "data", (data) ->
    test.equal data, null
  outA.on "disconnect", ->
  outB.on "disconnect", ->
  outC.on "disconnect", ->
    test.done()

  ins.connect()
  ins.send(1)
  ins.send(2)
  ins.disconnect()
