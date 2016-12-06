noflo = require 'noflo'
unless noflo.isBrowser()
  chai = require 'chai'
  path = require 'path'
  baseDir = path.resolve __dirname, '../'
else
  baseDir = 'noflo-routers'

describe 'PacketRegexpRouter', ->

  router = null
  loader = null

  before ->
    loader = new noflo.ComponentLoader baseDir
  beforeEach (done) ->
    @timeout 4000
    loader.load 'routers/PacketRegexpRouter', (err, instance) ->
      return done err if err
      router = instance
      done()

  describe 'available ports', ->

    describe 'inPorts', ->

      it 'should include "in"', ->
        chai.expect(router.inPorts.in).to.be.an 'object'

      it 'should include "route"', ->
        chai.expect(router.inPorts.route).to.be.an 'object'

    describe 'outPorts', ->

      it 'should include "out"', ->
        chai.expect(router.outPorts.out).to.be.an 'object'

      it 'should include "missed"', ->
        chai.expect(router.outPorts.missed).to.be.an 'object'

  describe 'data flow', ->

    describe 'on the "out" port', ->

      inIn = null
      routeIn = null
      outOut = null
      missedOut = null

      beforeEach ->
        inIn = noflo.internalSocket.createSocket()
        routeIn = noflo.internalSocket.createSocket()
        outOut = noflo.internalSocket.createSocket()
        missedOut = noflo.internalSocket.createSocket()

        router.inPorts.route.attach routeIn
        router.inPorts.in.attach inIn
        router.outPorts.out.attach outOut
        router.outPorts.missed.attach missedOut

      it 'should receive matches', (done) ->
        # Register a callback for successful routing.
        outOut.connect()
        outOut.on 'data', (data) ->
          chai.expect(data).to.equal 'abc'
          done()

        # Configure a route.
        routeIn.connect()
        routeIn.send ["^abc$"]
        routeIn.disconnect()

        # Send a packet that should match
        inIn.connect()
        inIn.send 'abc'
        inIn.disconnect()

      it 'should route matches by index', (done) ->
        # Add an additional connection to "out".
        outOut2 = noflo.internalSocket.createSocket()
        router.outPorts.out.attach outOut2
        outOut.connect()
        outOut2.connect()

        # Register a callback for successful routing.
        outOut2.on 'data', (data) ->
          chai.expect(data).to.equal 'def'
          done()

        # Configure a route.
        routeIn.connect()
        routeIn.send ["^abc$", "^def$"]
        routeIn.disconnect()

        # Send a packet that should match
        inIn.connect()
        inIn.send 'def'
        inIn.disconnect()

      it 'should not receive mismatches', ->
        # Register a callback for successful routing.
        outOut.connect()
        outOut.on 'data', (data) ->
          throw new Error '"out" should not receive a signal'

        # Configure a route.
        routeIn.connect()
        routeIn.send ["^abc$"]
        routeIn.disconnect()

        # Send a packet that should match
        inIn.connect()
        inIn.send 'cba'
        inIn.disconnect()

      it 'should persist groups', (done) ->
        # Register a callback for successful routing.
        outOut.connect()
        outOut.on 'begingroup', (group) ->
          chai.expect(group).to.equal 'group1'
          done()

        # Configure a route.
        routeIn.connect()
        routeIn.send ["^abc$"]
        routeIn.disconnect()

        # Send a packet that should match
        inIn.connect()
        inIn.beginGroup 'group1'
        inIn.send 'abc'
        inIn.endGroup 'group1'
        inIn.disconnect()

    describe 'of the "missed" port', ->

      describe 'on the "out" port', ->

      inIn = null
      routeIn = null
      outOut = null
      missedOut = null

      beforeEach ->
        inIn = noflo.internalSocket.createSocket()
        routeIn = noflo.internalSocket.createSocket()
        outOut = noflo.internalSocket.createSocket()
        missedOut = noflo.internalSocket.createSocket()

        router.inPorts.route.attach routeIn
        router.inPorts.in.attach inIn
        router.outPorts.out.attach outOut
        router.outPorts.missed.attach missedOut

      it 'should receive missed routes', (done) ->
        # Register a callback for successful routing.
        missedOut.connect()
        missedOut.on 'data', (data) ->
          chai.expect(data).to.equal 'cba'
          done()

        # Configure a route.
        routeIn.connect()
        routeIn.send ["^abc$"]
        routeIn.disconnect()

        # Send a packet that should match
        inIn.connect()
        inIn.send 'cba'
        inIn.disconnect()

      it 'should not received matched routes', ->
        # Register a callback for successful routing.
        missedOut.connect()
        missedOut.on 'data', (data) ->
          throw new Error '"out" should not receive a signal'

        # Configure a route.
        routeIn.connect()
        routeIn.send ["^abc$"]
        routeIn.disconnect()

        # Send a packet that should match
        inIn.connect()
        inIn.send 'abc'
        inIn.disconnect()
