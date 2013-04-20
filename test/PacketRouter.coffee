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

  test.expect(5)

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
  ins.beginGroup("d")
  ins.send("d")
  ins.endGroup("d")
  ins.disconnect()
