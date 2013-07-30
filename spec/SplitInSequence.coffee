noflo = require 'noflo'
if typeof process is 'object' and process.title is 'node'
  chai = require 'chai' unless chai
  SplitInSequence = require '../components/SplitInSequence.coffee'
else
  SplitInSequence = require 'routers/components/SplitInSequence.js'

describe 'SplitInSequence component', ->
  c = null
  ins = null
  out = null
  beforeEach ->
    c = SplitInSequence.getComponent()
    ins = noflo.internalSocket.createSocket()
    out = noflo.internalSocket.createSocket()
    c.inPorts.in.attach ins
    c.outPorts.out.attach out

  describe 'when instantiated', ->
    it 'should have an input port', ->
      chai.expect(c.inPorts.in).to.be.an 'object'
    it 'should have an output port', ->
      chai.expect(c.outPorts.out).to.be.an 'object'

  it 'test sending to single outport', (done) ->
    expects = [5, 1]
    sends = [5, 1]

    out.on 'data', (data) ->
      chai.expect(data).to.equal expects.shift()

    out.on 'disconnect', ->
      done()

    ins.send data for data in sends
    ins.disconnect()

  # it 'test sending to three outports', (done) ->
  #   sends = [1, 2, 3, 4, 5, 6]
  #   outs = [
  #     socket: noflo.internalSocket.createSocket()
  #     expects: [1, 4]
  #   ,
  #     socket: noflo.internalSocket.createSocket()
  #     expects: [2, 5]
  #   ,
  #     socket: noflo.internalSocket.createSocket()
  #     expects: [3, 6]
  #   ]

  #   disconnected = 0
  #   outs.forEach (out) ->
  #     c.outPorts.out.attach out.socket

  #     out.socket.on 'data', (data) ->
  #       chai.expect(out.expects.length).to.be.ok
  #       chai.expect(data).to.equal out.expects.shift()
  #     out.socket.on 'disconnect', ->
  #       disconnected++
  #       done() if disconnected is outs.length

  #   ins.send send for send in sends
  #   ins.disconnect()
