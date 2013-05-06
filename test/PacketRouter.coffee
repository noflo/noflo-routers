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

  outA.on "begingroup", (group) ->
    test.equal(group, "a")
  outA.on "data", (data) ->
    test.equal(data, "a")

  outB.on "begingroup", (group) ->
    test.ok(false, "there's no group for B")
  outB.on "data", (data) ->
    test.equal(data, "b")

  missedOut.on "data", (data) ->
    test.equal(data, expectedMissed.shift())
  missedOut.on "disconnect", ->
    test.done()

  ins.connect()
  ins.beginGroup("a")
  ins.send("a")
  ins.endGroup("a")
  # Even without group it's routed
  ins.send("b")
  ins.beginGroup("c")
  ins.send("c")
  ins.endGroup("c")
  ins.disconnect()

exports["works with nested groups too"] = (test) ->
  [c, [ins], [out]] = setup("PacketRouter", ["in"], ["out"])

  expected = ["a", "b", 1, "b", "c", 2, "c", "a"]

  testExpected = (item) ->
    test.equal(item, expected.shift())

  out.on "begingroup", (group) ->
    testExpected(group)
  out.on "data", (data) ->
    testExpected(data)
  out.on "endgroup", (group) ->
    testExpected(group)
  out.on "disconnect", ->
    test.done()

  ins.connect()
  ins.beginGroup("a")
  ins.beginGroup("b")
  ins.send(1)
  ins.endGroup("b")
  ins.beginGroup("c")
  ins.send(2)
  ins.endGroup("c")
  ins.endGroup("a")
  ins.disconnect()

exports["router still connects to unmatched ports"] = (test) ->
  [c, [ins], [outA, outB, outC]] = setup("PacketRouter", ["in"], ["out", "out", "out"])

  test.expect 3

  outA.on "data", (data) ->
    test.equal data, 1
  outB.on "data", (data) ->
    test.equal data, 2
  outC.on "connect", ->
    test.ok true
  outC.on "disconnect", ->
    test.done()

  ins.connect()
  ins.send(1)
  ins.send(2)
  ins.disconnect()
