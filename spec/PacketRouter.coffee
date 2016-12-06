noflo = require 'noflo'
unless noflo.isBrowser()
  chai = require 'chai'
  path = require 'path'
  baseDir = path.resolve __dirname, '../'
else
  baseDir = 'noflo-routers'

describe 'PacketRouter component', ->
  c = null
  ins = null
  outA = null
  outB = null
  outC = null
  missedOut = null
  loader = null

  before ->
    loader = new noflo.ComponentLoader baseDir
  beforeEach (done) ->
    @timeout 4000
    loader.load 'routers/PacketRouter', (err, instance) ->
      return done err if err
      c = instance
      ins = noflo.internalSocket.createSocket()
      outA = noflo.internalSocket.createSocket()
      outB = noflo.internalSocket.createSocket()
      outC = noflo.internalSocket.createSocket()
      missedOut = noflo.internalSocket.createSocket()
      c.inPorts.in.attach ins
      c.outPorts.missed.attach missedOut
      done()

  describe 'when instantiated', ->
    it 'should have an input port', ->
      chai.expect(c.inPorts.in).to.be.an 'object'
    it 'should have an output port', ->
      chai.expect(c.outPorts.out).to.be.an 'object'
      chai.expect(c.outPorts.missed).to.be.an 'object'

  it "routes incoming IPs based on IP stream position", (done) ->
    c.outPorts.out.attach outA
    c.outPorts.out.attach outB

    expectedMissed = ["c", "d"]

    outA.on "data", (data) ->
      chai.expect(data).to.equal "a"

    outB.on "data", (data) ->
      chai.expect(data).to.equal "b"

    missedOut.on "data", (data) ->
      chai.expect(data).to.equal expectedMissed.shift()
    missedOut.on "disconnect", ->
      done()

    ins.connect()
    ins.send("a")
    ins.send("b")
    ins.send("c")
    ins.disconnect()

  it "router still connects to unmatched ports", (done) ->
    c.outPorts.out.attach outA
    c.outPorts.out.attach outB
    c.outPorts.out.attach outC

    outA.on "data", (data) ->
      chai.expect(data).to.equal 1
    outB.on "data", (data) ->
      chai.expect(data).to.equal 2
    outC.on "data", (data) ->
      chai.expect(data).to.equal null
    outA.on "disconnect", ->
    outB.on "disconnect", ->
    outC.on "disconnect", ->
      done()

    ins.connect()
    ins.send(1)
    ins.send(2)
    ins.disconnect()
