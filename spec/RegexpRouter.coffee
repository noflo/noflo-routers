noflo = require 'noflo'
unless noflo.isBrowser()
  chai = require 'chai' unless chai
  RegexpRouter = require '../components/RegexpRouter.coffee'
else
  RegexpRouter = require 'routers/components/RegexpRouter.js'

describe 'RegexpRouter component', ->
  c = null
  ins = null
  routesIns = null
  resetIns = null
  outA = null
  outB = null
  missedOut = null
  routesOut = null

  beforeEach ->
    c = RegexpRouter.getComponent()
    ins = noflo.internalSocket.createSocket()
    routesIns = noflo.internalSocket.createSocket()
    resetIns = noflo.internalSocket.createSocket()
    outA = noflo.internalSocket.createSocket()
    outB = noflo.internalSocket.createSocket()
    missedOut = noflo.internalSocket.createSocket()
    routesOut = noflo.internalSocket.createSocket()
    c.inPorts.in.attach ins
    c.inPorts.route.attach routesIns
    c.inPorts.reset.attach resetIns
    c.outPorts.missed.attach missedOut
    c.outPorts.route.attach routesOut

  describe 'when instantiated', ->
    it 'should have an input port', ->
      chai.expect(c.inPorts.in).to.be.an 'object'
      chai.expect(c.inPorts.route).to.be.an 'object'
      chai.expect(c.inPorts.reset).to.be.an 'object'
    it 'should have an output port', ->
      chai.expect(c.outPorts.out).to.be.an 'object'
      chai.expect(c.outPorts.missed).to.be.an 'object'
      chai.expect(c.outPorts.route).to.be.an 'object'

  it "route incoming IPs based on RegExp (only the top-level)", (done) ->
    c.outPorts.out.attach outA
    c.outPorts.out.attach outB

    outA.on "begingroup", (group) ->
      chai.expect(group).to.equal "group"
    outA.on "data", (data) ->
      chai.expect(data).to.equal "abc"
    outB.on "data", (data) ->
      chai.expect(data).to.equal "xyz"
    missedOut.on "data", (data) ->
      chai.expect(data).to.equal "missed"
    missedOut.on "disconnect", ->
      done()

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

  it "reset the routes", (done) ->
    c.outPorts.out.attach outA
    c.outPorts.out.attach outB

    outA.on "data", (data) ->
      chai.expect(data).to.equal "abc"
    missedOut.on "disconnect", ->
      done()

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
