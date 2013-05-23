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

exports["route incoming IPs based on group routes"] = (test) ->
  [c, [routesIns, ins], [outA, outB, outC, outD, missedOut]] = setup("GroupRouter", ["route", "in"], ["out", "out", "out", "out", "missed"])

  outA.on "data", (data) ->
    test.equal(data, "a/b")
  outB.on "data", (data) ->
    test.equal(data, "d")
  outC.on "data", (data) ->
    test.equal(data, "e")
  outD.on "data", (data) ->
    test.ok(false, "should not be sent anything due to lack of qualified IPs")
  missedOut.on "data", (data) ->
    test.equal(data, "missed")
  outC.on "disconnect", ->
    test.done()

  # Each route contains a linear hierarchy of groups separated by slashes.
  # `["a", "b"]` matches only if group `b` is enclosed within group `a`.
  # Matches are sent to the port corresponding to the order in which routes
  # were received. So if a later-defined route is identical to an
  # earlier-defined route, the earlier-defined route always receives the
  # matches.
  routesIns.connect()
  routesIns.send(["a", "b"])
  routesIns.send("d")
  routesIns.send(["a", "e.+"])
  routesIns.send(["a", "g"])
  routesIns.disconnect()

  ins.connect()
  ins.beginGroup("a")
  ins.send("missed")
  ins.beginGroup("b")
  ins.send("a/b")
  ins.endGroup("b")
  ins.beginGroup("c")
  ins.send("missed")
  ins.endGroup("c")
  ins.endGroup("a")
  # As long as "d" is matched and there's no subsequent route segment, any
  # subsequent group doesn't count in determining whether this is a match or
  # not
  ins.beginGroup("d")
  ins.beginGroup("e")
  ins.send("d")
  ins.endGroup("e")
  ins.endGroup("d")
  ins.beginGroup("a")
  ins.beginGroup("ea")
  ins.send("e")
  ins.endGroup("ea")
  ins.endGroup("a")
  ins.disconnect()

exports["matched groups are stripped"] = (test) ->
  [c, [routesIns, ins], [out, missedOut]] = setup("GroupRouter", ["route", "in"], ["out", "missed"])

  test.expect 2

  out.on "begingroup", (group) ->
    test.equal group, "c"
  out.on "data", (data) ->
    test.equal data, "x"

  missedOut.on "begingroup", (group) ->
    test.ok(false, "should not be called")
  missedOut.on "data", (data) ->
    test.ok(false, "should not be called")
  missedOut.on "endgroup", (group) ->
    test.ok(false, "should not be called")

  out.on "disconnect", ->
    test.done()

  routesIns.connect()
  routesIns.send(["a", "b"])
  routesIns.disconnect()

  ins.connect()
  ins.beginGroup("a")
  ins.beginGroup("b")
  ins.beginGroup("c")
  ins.send("x")
  ins.endGroup("c")
  ins.endGroup("b")
  ins.endGroup("a")
  ins.disconnect()

exports["the matched path will also be output"] = (test) ->
  [c, [routesIns, ins], [out, routesOut]] = setup("GroupRouter", ["route", "in"], ["out", "route"])

  routesOut.on "data", (data) ->
    test.deepEqual(data, [/a/, /b/])
  routesOut.on "disconnect", ->
    test.done()

  routesIns.connect()
  routesIns.send(["a", "b"])
  routesIns.disconnect()

  ins.connect()
  ins.beginGroup("a")
  ins.beginGroup("b")
  ins.beginGroup("c")
  ins.send("x")
  ins.endGroup("c")
  ins.endGroup("b")
  ins.endGroup("a")
  ins.disconnect()

exports["reset the routes"] = (test) ->
  [c, [resetIns, routesIns, ins], [outA, outB, missedOut]] = setup("GroupRouter", ["reset", "route", "in"], ["out", "out", "missed"])

  outA.on "data", (data) ->
    test.equal(data, "abc")
  missedOut.on "disconnect", ->
    test.done()

  routesIns.connect()
  routesIns.send(["a", "b"])
  routesIns.disconnect()

  resetIns.connect()
  resetIns.disconnect()

  routesIns.connect()
  routesIns.send(["c"])
  routesIns.disconnect()

  ins.connect()
  ins.beginGroup("a")
  ins.beginGroup("b")
  ins.send("missed")
  ins.endGroup("b")
  ins.endGroup("a")
  ins.beginGroup("c")
  ins.send("abc")
  ins.endGroup("c")
  ins.disconnect()


## Test for compatbility with legacy GroupRouter. Do not use these as examples.

exports["test routing error"] = (test) ->
  test.expect 1
  [c, [routes, src], [missed]] = setup("GroupRouter", ["routes", "in"], ["missed"])
  routes.send "foo,bar"
  missed.once "data", (data) ->
    test.equal data, "hello"
    test.done()
  src.connect()
  src.beginGroup "baz"
  src.send "hello"
  src.disconnect()

exports["test routing success"] = (test) ->
  test.expect 1
  [c, [routes, src], [missed]] = setup("GroupRouter", ["routes", "in"], ["missed"])
  routes.send "foo,bar"
  dst1 = Socket.createSocket()
  dst2 = Socket.createSocket()
  c.outPorts.out.attach dst1
  c.outPorts.out.attach dst2
  dst2.once "data", (data) ->
    test.equal data, "hello"
    test.done()
  src.connect()
  src.beginGroup "bar"
  src.send "hello"
  src.disconnect()

exports["test routing subgroup error"] = (test) ->
  test.expect 1
  [c, [routes, src], [missed]] = setup("GroupRouter", ["routes", "in"], ["missed"])
  routes.send "foo:baz,bar:baz"
  missed.once "data", (data) ->
    test.equal data, "hello"
    test.done()
  src.connect()
  src.beginGroup "bar"
  src.send "hello"
  src.disconnect()

exports["test routing subgroup success"] = (test) ->
  test.expect 1
  [c, [routes, src], [missed]] = setup("GroupRouter", ["routes", "in"], ["missed"])
  routes.send "foo:baz,bar:baz"
  dst1 = Socket.createSocket()
  dst2 = Socket.createSocket()
  c.outPorts.out.attach dst1
  c.outPorts.out.attach dst2
  dst2.once "data", (data) ->
    test.equal data, "hello"
    test.done()
  src.connect()
  src.beginGroup "bar"
  src.beginGroup "baz"
  src.send "hello"
  src.disconnect()
