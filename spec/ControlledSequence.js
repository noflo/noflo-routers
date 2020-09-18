/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
describe('ControlledSequence component', () => {
  let c = null;
  let next = null;
  let ins = null;
  let outs = [];
  before(function (done) {
    this.timeout(4000);
    const loader = new noflo.ComponentLoader(baseDir);
    return loader.load('routers/ControlledSequence', (err, instance) => {
      if (err) { return done(err); }
      c = instance;
      ins = noflo.internalSocket.createSocket();
      next = noflo.internalSocket.createSocket();
      c.inPorts.in.attach(ins);
      c.inPorts.next.attach(next);
      return done();
    });
  });
  beforeEach(() => {
    outs = [];
    outs.push(noflo.internalSocket.createSocket());
    outs.push(noflo.internalSocket.createSocket());
    outs.push(noflo.internalSocket.createSocket());
    outs.push(noflo.internalSocket.createSocket());
    c.outPorts.out.attach(outs[0]);
    c.outPorts.out.attach(outs[1]);
    c.outPorts.out.attach(outs[2]);
    return c.outPorts.out.attach(outs[3]);
  });
  afterEach((done) => {
    c.outPorts.out.detach(outs[0]);
    c.outPorts.out.detach(outs[1]);
    c.outPorts.out.detach(outs[2]);
    c.outPorts.out.detach(outs[3]);
    return c.shutdown(done);
  });

  return describe('sending packets', () => {
    it('should switch connection when receiving a next', (done) => {
      const expected = [
        '0 < foo',
        '0 DATA a',
        '0 >',
        '1 DATA b',
      ];
      const received = [];
      outs.forEach((socket, idx) => {
        socket.on('begingroup', (group) => received.push(`${idx} < ${group}`));
        socket.on('data', (data) => {
          received.push(`${idx} DATA ${data}`);
          if (received.length !== expected.length) { return; }
          chai.expect(received).to.eql(expected);
          return done();
        });
        return socket.on('endgroup', (group) => {
          received.push(`${idx} >`);
          if (received.length !== expected.length) { return; }
          chai.expect(received).to.eql(expected);
          return done();
        });
      });
      ins.beginGroup('foo');
      ins.send('a');
      ins.endGroup();
      next.send(null);
      return ins.send('b');
    });
    return it('should switch back to first connection when running out of connections', (done) => {
      const expected = [
        '3 < foo',
        '3 DATA a',
        '3 >',
        '0 DATA b',
      ];
      const received = [];
      outs.forEach((socket, idx) => {
        socket.on('begingroup', (group) => received.push(`${idx} < ${group}`));
        socket.on('data', (data) => {
          received.push(`${idx} DATA ${data}`);
          if (received.length !== expected.length) { return; }
          chai.expect(received).to.eql(expected);
          return done();
        });
        return socket.on('endgroup', (group) => {
          received.push(`${idx} >`);
          if (received.length !== expected.length) { return; }
          chai.expect(received).to.eql(expected);
          return done();
        });
      });
      next.send(null);
      next.send(null);
      next.send(null);
      ins.beginGroup('foo');
      ins.send('a');
      ins.endGroup();
      next.send(null);
      return ins.send('b');
    });
  });
});
