noflo = require 'noflo'
unless noflo.isBrowser()
  chai = require 'chai'
  path = require 'path'
  baseDir = path.resolve __dirname, '../'
else
  baseDir = 'noflo-routers'

describe 'RegexpRouter component', ->
  c = null
  ins = null
  routesIns = null
  resetIns = null
  sendTopLevel = null
  outA = null
  outB = null
  missedOut = null
  routesOut = null
  loader = null

  before ->
    loader = new noflo.ComponentLoader baseDir
  beforeEach (done) ->
    @timeout 4000
    loader.load 'routers/RegexpRouter', (err, instance) ->
      return done err if err
      c = instance
      ins = noflo.internalSocket.createSocket()
      routesIns = noflo.internalSocket.createSocket()
      resetIns = noflo.internalSocket.createSocket()
      sendTopLevel = noflo.internalSocket.createSocket()
      outA = noflo.internalSocket.createSocket()
      outB = noflo.internalSocket.createSocket()
      missedOut = noflo.internalSocket.createSocket()
      routesOut = noflo.internalSocket.createSocket()
      c.inPorts.in.attach ins
      c.inPorts.route.attach routesIns
      c.inPorts.reset.attach resetIns
      c.inPorts.sendtoplevel.attach sendTopLevel
      c.outPorts.missed.attach missedOut
      c.outPorts.route.attach routesOut
      done()

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

  it "route incoming IPs based on RegExp (only the top-level), sending all groups", (done) ->
    c.outPorts.out.attach outA
    c.outPorts.out.attach outB

    expA = ['abc', 'group']
    toEndA = expA.length
    expMissed = ['cba']
    toEndMissed = expMissed.length

    outA.on "begingroup", (group) ->
      chai.expect(group).to.equal expA.shift()
    outA.on "data", (data) ->
      chai.expect(data).to.equal "abc"
    outA.on "endgroup", ->
      toEndA--
    outB.on "data", (data) ->
      chai.expect(data).to.equal "xyz"
    missedOut.on "begingroup", (group) ->
      chai.expect(group).to.equal expMissed.shift()
    missedOut.on "data", (data) ->
      chai.expect(data).to.equal "missed"
    missedOut.on "endgroup", ->
      toEndMissed--
    missedOut.on "disconnect", ->
      chai.expect(expA.length).to.equal 0
      chai.expect(toEndA).to.equal 0
      chai.expect(expMissed.length).to.equal 0
      chai.expect(toEndMissed).to.equal 0
      done()

    sendTopLevel.send true
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
