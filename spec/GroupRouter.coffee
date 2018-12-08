describe 'GroupRouter component', ->
  receive = (outs, missedOut, expected, done) ->
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
        received.push "#{idx} > #{group}"
        return unless received.length is expected.length
        chai.expect(received).to.eql expected
        done()
    if missedOut
      missedOut.on 'begingroup', (group) ->
        received.push "MISSED < #{group}"
      missedOut.on 'data', (data) ->
        received.push "MISSED DATA #{data}"
        return unless received.length is expected.length
        chai.expect(received).to.eql expected
        done()
      missedOut.on 'endgroup', (group) ->
        received.push "MISSED >"
        return unless received.length is expected.length
        chai.expect(received).to.eql expected
        done()

  c = null
  routeIns = null
  routesIns = null
  resetIns = null
  ins = null
  outs = []
  routeOut = null
  missedOut = null
  loader = null

  before ->
    loader = new noflo.ComponentLoader baseDir
  beforeEach (done) ->
    @timeout 4000
    loader.load 'routers/GroupRouter', (err, instance) ->
      return done err if err
      c = instance
      ins = noflo.internalSocket.createSocket()
      routeIns = noflo.internalSocket.createSocket()
      routesIns = noflo.internalSocket.createSocket()
      resetIns = noflo.internalSocket.createSocket()
      outs.push noflo.internalSocket.createSocket()
      outs.push noflo.internalSocket.createSocket()
      outs.push noflo.internalSocket.createSocket()
      outs.push noflo.internalSocket.createSocket()
      routeOut = noflo.internalSocket.createSocket()
      missedOut = noflo.internalSocket.createSocket()

      c.inPorts.in.attach ins
      c.inPorts.route.attach routeIns
      c.inPorts.routes.attach routesIns
      c.inPorts.reset.attach resetIns
      c.outPorts.route.attach routeOut
      c.outPorts.missed.attach missedOut
      for socket in outs
        c.outPorts.out.attach socket
      done()

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
    it "route incoming IPs based on group routes", (done) ->
      expected = [
        'MISSED < a'
        'MISSED DATA missed'
        '0 DATA a/b'
        'MISSED < c'
        'MISSED DATA missed'
        'MISSED >'
        'MISSED >'
        '1 < e'
        '1 DATA d'
        '1 > e'
        'MISSED < a'
        '2 DATA e'
        'MISSED >'
      ]
      receive outs, missedOut, expected, done

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
      expected = [
        'MISSED < a'
        '0 < c'
        '0 DATA x'
        '0 > c'
        'MISSED >'
      ]
      receive outs, missedOut, expected, done

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
      expected = [
        'MISSED < a'
        'MISSED < b'
        'MISSED DATA missed'
        'MISSED >'
        'MISSED >'
        '0 DATA abc'
      ]
      receive outs, missedOut, expected, done

      routeIns.connect()
      routeIns.send(["a", "b"])
      routeIns.disconnect()

      resetIns.connect()
      resetIns.send null
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
      expected = [
        'MISSED < baz'
        'MISSED DATA hello'
        'MISSED >'
      ]
      receive outs, missedOut, expected, done

      routesIns.send "foo,bar"
      ins.connect()
      ins.beginGroup "baz"
      ins.send "hello"
      ins.endGroup()
      ins.disconnect()

    it "test routing success", (done) ->
      routesIns.send "foo,bar"
      expected = [
        '1 DATA hello'
      ]
      receive outs, missedOut, expected, done
      ins.connect()
      ins.beginGroup "bar"
      ins.send "hello"
      ins.endGroup()
      ins.disconnect()

    it "test routing subgroup error", (done) ->
      routesIns.send "foo:baz,bar:baz"
      expected = [
        'MISSED < bar'
        'MISSED DATA hello'
        'MISSED >'
      ]
      receive outs, missedOut, expected, done

      ins.connect()
      ins.beginGroup "bar"
      ins.send "hello"
      ins.endGroup()
      ins.disconnect()

    it "test routing subgroup success", (done) ->
      routesIns.send "foo:baz,bar:baz"
      expected = [
        'MISSED < bar'
        '1 DATA hello'
        'MISSED >'
      ]
      receive outs, missedOut, expected, done

      ins.connect()
      ins.beginGroup "bar"
      ins.beginGroup "baz"
      ins.send "hello"
      ins.endGroup()
      ins.endGroup()
      ins.disconnect()

    it "test routing group wildcards", (done) ->
      routesIns.send "bar,.*"
      expected = [
        '1 DATA hello'
      ]
      receive outs, missedOut, expected, done

      ins.connect()
      ins.beginGroup "baz"
      ins.send "hello"
      ins.endGroup()
      ins.disconnect()

    it "test routing subgroup wildcards", (done) ->
      routesIns.send "foo:baz,bar:.*"
      expected = [
        'MISSED < bar'
        '1 DATA hello'
        'MISSED >'
      ]
      receive outs, missedOut, expected, done

      ins.connect()
      ins.beginGroup "bar"
      ins.beginGroup "baz"
      ins.send "hello"
      ins.endGroup()
      ins.endGroup()
      ins.disconnect()

    it "test routing primary group wildcards", (done) ->
      routesIns.send "foo:baz,.*:baz"
      expected = [
        'MISSED < bar'
        '1 DATA hello'
        'MISSED >'
      ]
      receive outs, missedOut, expected, done

      ins.beginGroup "bar"
      ins.beginGroup "baz"
      ins.send "hello"
      ins.endGroup()
      ins.endGroup()
      ins.disconnect()
