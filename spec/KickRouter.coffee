noflo = require 'noflo'
unless noflo.isBrowser()
  chai = require 'chai'
  path = require 'path'
  baseDir = path.resolve __dirname, '../'
else
  baseDir = 'noflo-routers'

describe 'KickRouter component', ->
  c = null
  next = null
  prev = null
  index = null
  ins = null
  outs = []
  before (done) ->
    @timeout 4000
    loader = new noflo.ComponentLoader baseDir
    loader.load 'routers/KickRouter', (err, instance) ->
      return done err if err
      c = instance
      ins = noflo.internalSocket.createSocket()
      next = noflo.internalSocket.createSocket()
      prev = noflo.internalSocket.createSocket()
      index = noflo.internalSocket.createSocket()
      c.inPorts.in.attach ins
      c.inPorts.next.attach next
      c.inPorts.prev.attach prev
      c.inPorts.index.attach index
      done()
  beforeEach ->
    outs = []
    outs.push noflo.internalSocket.createSocket()
    outs.push noflo.internalSocket.createSocket()
    outs.push noflo.internalSocket.createSocket()
    outs.push noflo.internalSocket.createSocket()
    c.outPorts.out.attach outs[0]
    c.outPorts.out.attach outs[1]
    c.outPorts.out.attach outs[2]
    c.outPorts.out.attach outs[3]
  afterEach (done) ->
    c.outPorts.out.detach outs[0]
    c.outPorts.out.detach outs[1]
    c.outPorts.out.detach outs[2]
    c.outPorts.out.detach outs[3]
    c.shutdown done

  describe 'receiving a next', ->
    it 'should release a stream to next index', (done) ->
      expected = [
        '1 < foo'
        '1 DATA a'
        '1 >'
        '2 DATA b'
      ]
      received = []
      outs.forEach (socket, idx) ->
        socket.on 'begingroup', (group) ->
          received.push "#{idx} < #{group}"
        socket.on 'data', (data) ->
          received.push "#{idx} DATA #{data}"
          return unless received.length is expected.length
          chai.expect(received).to.eql expected
          done()
        socket.on 'endgroup', (group) ->
          received.push "#{idx} >"
          return unless received.length is expected.length
          chai.expect(received).to.eql expected
          done()
      ins.beginGroup 'foo'
      ins.send 'a'
      ins.endGroup()
      next.send null
      ins.send 'b'
      next.send null
  describe 'receiving a prev', ->
    it 'should release a stream to previous index', (done) ->
      expected = [
        '3 < foo'
        '3 DATA a'
        '3 >'
        '2 DATA b'
      ]
      received = []
      outs.forEach (socket, idx) ->
        socket.on 'begingroup', (group) ->
          received.push "#{idx} < #{group}"
        socket.on 'data', (data) ->
          received.push "#{idx} DATA #{data}"
          return unless received.length is expected.length
          chai.expect(received).to.eql expected
          done()
        socket.on 'endgroup', (group) ->
          received.push "#{idx} >"
          return unless received.length is expected.length
          chai.expect(received).to.eql expected
          done()
      ins.beginGroup 'foo'
      ins.send 'a'
      ins.endGroup()
      prev.send null
      ins.send 'b'
      prev.send null
  describe 'receiving an index', ->
    it 'should release a stream to given index', (done) ->
      expected = [
        '0 < foo'
        '0 DATA a'
        '0 >'
        '2 DATA b'
      ]
      received = []
      outs.forEach (socket, idx) ->
        socket.on 'begingroup', (group) ->
          received.push "#{idx} < #{group}"
        socket.on 'data', (data) ->
          received.push "#{idx} DATA #{data}"
          return unless received.length is expected.length
          chai.expect(received).to.eql expected
          done()
        socket.on 'endgroup', (group) ->
          received.push "#{idx} >"
          return unless received.length is expected.length
          chai.expect(received).to.eql expected
          done()
      ins.beginGroup 'foo'
      ins.send 'a'
      ins.endGroup()
      index.send 0
      ins.send 'b'
      index.send 2
