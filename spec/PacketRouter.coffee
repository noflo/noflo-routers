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

    expected = [
      'a a'
      'b b'
      'missed c'
      'missed d'
    ]
    received = []

    outA.on "data", (data) ->
      received.push "a #{data}"
      return unless received.length is expected.length
      chai.expect(received).to.eql expected
      done()

    outB.on "data", (data) ->
      received.push "b #{data}"
      return unless received.length is expected.length
      chai.expect(received).to.eql expected
      done()

    missedOut.on "data", (data) ->
      received.push "missed #{data}"
      return unless received.length is expected.length
      chai.expect(received).to.eql expected
      done()

    ins.beginGroup()
    ins.send("a")
    ins.send("b")
    ins.send("c")
    ins.send("d")
    ins.endGroup()
