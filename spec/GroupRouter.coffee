noflo = require 'noflo'
unless noflo.isBrowser()
  chai = require 'chai' unless chai
  GroupRouter = require '../components/GroupRouter.coffee'
else
  GroupRouter = require 'noflo-routers/components/GroupRouter.js'

describe 'GroupRouter component', ->
  c = null
  routeIns = null
  routesIns = null
  resetIns = null
  ins = null
  outA = null
  outB = null
  outC = null
  outD = null
  routeOut = null
  missedOut = null

  beforeEach ->
    c = GroupRouter.getComponent()
    ins = noflo.internalSocket.createSocket()
    routeIns = noflo.internalSocket.createSocket()
    routesIns = noflo.internalSocket.createSocket()
    resetIns = noflo.internalSocket.createSocket()
    outA = noflo.internalSocket.createSocket()
    outB = noflo.internalSocket.createSocket()
    outC = noflo.internalSocket.createSocket()
    outD = noflo.internalSocket.createSocket()
    routeOut = noflo.internalSocket.createSocket()
    missedOut = noflo.internalSocket.createSocket()

    c.inPorts.in.attach ins
    c.inPorts.route.attach routeIns
    c.inPorts.routes.attach routesIns
    c.inPorts.reset.attach resetIns
    c.outPorts.route.attach routeOut
    c.outPorts.missed.attach missedOut

  describe 'when instantiated', ->
    it 'should have an input port', ->
      chai.expect(c.inPorts.in).to.be.an 'object'
      chai.expect(c.inPorts.route).to.be.an 'object'
      chai.expect(c.inPorts.reset).to.be.an 'object'
    it 'should have an output port', ->
      chai.expect(c.outPorts.out).to.be.an 'object'
      chai.expect(c.outPorts.route).to.be.an 'object'
      chai.expect(c.outPorts.missed).to.be.an 'object'


  describe 'tests', ->
    beforeEach ->
      c.outPorts.out.attach outA
      c.outPorts.out.attach outB
      c.outPorts.out.attach outC
      c.outPorts.out.attach outD

    it "route incoming IPs based on group routes", (done) ->
      count = 0

      # Make sure connections are not nested
      outA.on "data", (data) ->
        chai.expect(data).to.equal "a/b"
        chai.expect(count++).to.equal 0
      outB.on "data", (data) ->
        chai.expect(data).to.equal "d"
        chai.expect(count++).to.equal 2
      outC.on "data", (data) ->
        chai.expect(data).to.equal "e"
        chai.expect(count++).to.equal 4
      outD.on "data", (data) ->
        chai.expect(false).to.be.ok
      missedOut.on "data", (data) ->
        chai.expect(data).to.equal "missed"
      outA.on "disconnect", ->
        chai.expect(count++).to.equal 1
      outB.on "disconnect", ->
        chai.expect(count++).to.equal 3
      outC.on "disconnect", ->
        chai.expect(count++).to.equal 5
        done()

      # Each route contains a linear hierarchy of groups separated by slashes.
      # `["a", "b"]` matches only if group `b` is enclosed within group `a`.
      # Matches are sent to the port corresponding to the order in which routes
      # were received. So if a later-defined route is identical to an
      # earlier-defined route, the earlier-defined route always receives the
      # matches.
      routeIns.connect()
      routeIns.send(["a", "b"])
      routeIns.send("d")
      routeIns.send(["a", "e.+"])
      routeIns.send(["a", "g"])
      routeIns.disconnect()

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

    it "matched groups are stripped", (done) ->
      outA.on "begingroup", (group) ->
        chai.expect(group).to.equal "c"
      outA.on "data", (data) ->
        chai.expect(data).to.equal "x"

      missedOut.on "begingroup", (group) ->
        chai.expect(group).to.equal 'a'
      missedOut.on "data", (data) ->
        chai.expect(false).to.be.ok
      missedOut.on "endgroup", (group) ->
        chai.expect(group).to.equal 'a'

      outA.on "disconnect", ->
        done()

      routeIns.connect()
      routeIns.send(["a", "b"])
      routeIns.disconnect()

      ins.connect()
      ins.beginGroup("a")
      ins.beginGroup("b")
      ins.beginGroup("c")
      ins.send("x")
      ins.endGroup("c")
      ins.endGroup("b")
      ins.endGroup("a")
      ins.disconnect()

    it "the matched path will also be output", (done) ->
      routeOut.on "data", (data) ->
        chai.expect(data).to.deep.equal [/a/, /b/]
      routeOut.on "disconnect", ->
        done()

      routeIns.connect()
      routeIns.send(["a", "b"])
      routeIns.disconnect()

      ins.connect()
      ins.beginGroup("a")
      ins.beginGroup("b")
      ins.beginGroup("c")
      ins.send("x")
      ins.endGroup("c")
      ins.endGroup("b")
      ins.endGroup("a")
      ins.disconnect()

    it "reset the routes", (done) ->
      outA.on "data", (data) ->
        chai.expect(data).to.equal "abc"
      missedOut.on "disconnect", ->
        done()

      routeIns.connect()
      routeIns.send(["a", "b"])
      routeIns.disconnect()

      resetIns.connect()
      resetIns.disconnect()

      routeIns.connect()
      routeIns.send(["c"])
      routeIns.disconnect()

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

  describe 'legacy test', ->
    it "test routing error", (done) ->
      routesIns.send "foo,bar"
      missedOut.once "data", (data) ->
        chai.expect(data).to.equal "hello"
        done()
      ins.connect()
      ins.beginGroup "baz"
      ins.send "hello"
      ins.endGroup()
      ins.disconnect()

    it "test routing success", (done) ->
      routesIns.send "foo,bar"
      dst1 = noflo.internalSocket.createSocket()
      dst2 = noflo.internalSocket.createSocket()
      c.outPorts.out.attach dst1
      c.outPorts.out.attach dst2
      dst2.once "data", (data) ->
        chai.expect(data).to.equal "hello"
        done()
      ins.connect()
      ins.beginGroup "bar"
      ins.send "hello"
      ins.endGroup()
      ins.disconnect()

    it "test routing subgroup error", (done) ->
      routesIns.send "foo:baz,bar:baz"
      missedOut.once "data", (data) ->
        chai.expect(data).to.equal "hello"
        done()
      ins.connect()
      ins.beginGroup "bar"
      ins.send "hello"
      ins.endGroup()
      ins.disconnect()

    it "test routing subgroup success", (done) ->
      routesIns.send "foo:baz,bar:baz"
      dst1 = noflo.internalSocket.createSocket()
      dst2 = noflo.internalSocket.createSocket()
      c.outPorts.out.attach dst1
      c.outPorts.out.attach dst2
      dst2.once "data", (data) ->
        chai.expect(data).to.equal "hello"
        done()
      ins.connect()
      ins.beginGroup "bar"
      ins.beginGroup "baz"
      ins.send "hello"
      ins.endGroup()
      ins.endGroup()
      ins.disconnect()

    it "test routing group wildcards", (done) ->
      routesIns.send "bar,.*"
      dst1 = noflo.internalSocket.createSocket()
      dst2 = noflo.internalSocket.createSocket()
      c.outPorts.out.attach dst1
      c.outPorts.out.attach dst2
      dst2.once "data", (data) ->
        chai.expect(data).to.equal "hello"
        done()
      ins.connect()
      ins.beginGroup "baz"
      ins.send "hello"
      ins.endGroup()
      ins.disconnect()

    it "test routing subgroup wildcards", (done) ->
      routesIns.send "foo:baz,bar:.*"
      dst1 = noflo.internalSocket.createSocket()
      dst2 = noflo.internalSocket.createSocket()
      c.outPorts.out.attach dst1
      c.outPorts.out.attach dst2
      dst2.once "data", (data) ->
        chai.expect(data).to.equal "hello"
        done()
      ins.connect()
      ins.beginGroup "bar"
      ins.beginGroup "baz"
      ins.send "hello"
      ins.endGroup()
      ins.endGroup()
      ins.disconnect()

    it "test routing primary group wildcards", (done) ->
      routesIns.send "foo:baz,.*:baz"
      dst1 = noflo.internalSocket.createSocket()
      dst2 = noflo.internalSocket.createSocket()
      c.outPorts.out.attach dst1
      c.outPorts.out.attach dst2
      dst2.once "data", (data) ->
        chai.expect(data).to.equal "hello"
        done()
      ins.connect()
      ins.beginGroup "bar"
      ins.beginGroup "baz"
      ins.send "hello"
      ins.endGroup()
      ins.endGroup()
      ins.disconnect()
