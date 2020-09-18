/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
describe('PacketRegexpRouter', () => {
  let router = null;
  let loader = null;

  before(() => loader = new noflo.ComponentLoader(baseDir));
  beforeEach(function (done) {
    this.timeout(4000);
    return loader.load('routers/PacketRegexpRouter', (err, instance) => {
      if (err) { return done(err); }
      router = instance;
      return done();
    });
  });

  describe('available ports', () => {
    describe('inPorts', () => {
      it('should include "in"', () => chai.expect(router.inPorts.in).to.be.an('object'));

      return it('should include "route"', () => chai.expect(router.inPorts.route).to.be.an('object'));
    });

    return describe('outPorts', () => {
      it('should include "out"', () => chai.expect(router.outPorts.out).to.be.an('object'));

      return it('should include "missed"', () => chai.expect(router.outPorts.missed).to.be.an('object'));
    });
  });

  return describe('data flow', () => {
    describe('on the "out" port', () => {
      let inIn = null;
      let routeIn = null;
      let outOut = null;
      let missedOut = null;

      beforeEach(() => {
        inIn = noflo.internalSocket.createSocket();
        routeIn = noflo.internalSocket.createSocket();
        outOut = noflo.internalSocket.createSocket();
        missedOut = noflo.internalSocket.createSocket();

        router.inPorts.route.attach(routeIn);
        router.inPorts.in.attach(inIn);
        router.outPorts.out.attach(outOut);
        return router.outPorts.missed.attach(missedOut);
      });

      it('should receive matches', (done) => {
        // Register a callback for successful routing.
        outOut.connect();
        outOut.on('data', (data) => {
          chai.expect(data).to.equal('abc');
          return done();
        });

        // Configure a route.
        routeIn.connect();
        routeIn.send(['^abc$']);
        routeIn.disconnect();

        // Send a packet that should match
        inIn.connect();
        inIn.send('abc');
        return inIn.disconnect();
      });

      it('should route matches by index', (done) => {
        // Add an additional connection to "out".
        const outOut2 = noflo.internalSocket.createSocket();
        router.outPorts.out.attach(outOut2);
        outOut.connect();
        outOut2.connect();

        // Register a callback for successful routing.
        outOut2.on('data', (data) => {
          chai.expect(data).to.equal('def');
          return done();
        });

        // Configure a route.
        routeIn.connect();
        routeIn.send(['^abc$', '^def$']);
        routeIn.disconnect();

        // Send a packet that should match
        inIn.connect();
        inIn.send('def');
        return inIn.disconnect();
      });

      it('should not receive mismatches', () => {
        // Register a callback for successful routing.
        outOut.connect();
        outOut.on('data', (data) => {
          throw new Error('"out" should not receive a signal');
        });

        // Configure a route.
        routeIn.connect();
        routeIn.send(['^abc$']);
        routeIn.disconnect();

        // Send a packet that should match
        inIn.connect();
        inIn.send('cba');
        return inIn.disconnect();
      });

      return it('should persist groups', (done) => {
        // Register a callback for successful routing.
        outOut.connect();
        outOut.on('begingroup', (group) => {
          chai.expect(group).to.equal('group1');
          return done();
        });

        // Configure a route.
        routeIn.connect();
        routeIn.send(['^abc$']);
        routeIn.disconnect();

        // Send a packet that should match
        inIn.connect();
        inIn.beginGroup('group1');
        inIn.send('abc');
        inIn.endGroup('group1');
        return inIn.disconnect();
      });
    });

    return describe('of the "missed" port', () => {
      describe('on the "out" port', () => {});

      let inIn = null;
      let routeIn = null;
      let outOut = null;
      let missedOut = null;

      beforeEach(() => {
        inIn = noflo.internalSocket.createSocket();
        routeIn = noflo.internalSocket.createSocket();
        outOut = noflo.internalSocket.createSocket();
        missedOut = noflo.internalSocket.createSocket();

        router.inPorts.route.attach(routeIn);
        router.inPorts.in.attach(inIn);
        router.outPorts.out.attach(outOut);
        return router.outPorts.missed.attach(missedOut);
      });

      it('should receive missed routes', (done) => {
        // Register a callback for successful routing.
        missedOut.connect();
        missedOut.on('data', (data) => {
          chai.expect(data).to.equal('cba');
          return done();
        });

        // Configure a route.
        routeIn.connect();
        routeIn.send(['^abc$']);
        routeIn.disconnect();

        // Send a packet that should match
        inIn.connect();
        inIn.send('cba');
        return inIn.disconnect();
      });

      return it('should not received matched routes', () => {
        // Register a callback for successful routing.
        missedOut.connect();
        missedOut.on('data', (data) => {
          throw new Error('"out" should not receive a signal');
        });

        // Configure a route.
        routeIn.connect();
        routeIn.send(['^abc$']);
        routeIn.disconnect();

        // Send a packet that should match
        inIn.connect();
        inIn.send('abc');
        return inIn.disconnect();
      });
    });
  });
});
