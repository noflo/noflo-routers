/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
describe('SplitInSequence component', () => {
  let c = null;
  let ins = null;
  let out = null;
  let loader = null;

  before(() => loader = new noflo.ComponentLoader(baseDir));
  beforeEach(function (done) {
    this.timeout(4000);
    return loader.load('routers/SplitInSequence', (err, instance) => {
      if (err) { return done(err); }
      c = instance;
      ins = noflo.internalSocket.createSocket();
      c.inPorts.in.attach(ins);
      return done();
    });
  });

  describe('when instantiated', () => {
    it('should have an input port', () => chai.expect(c.inPorts.in).to.be.an('object'));
    return it('should have an output port', () => chai.expect(c.outPorts.out).to.be.an('object'));
  });

  it('test sending to single outport', (done) => {
    out = noflo.internalSocket.createSocket();
    c.outPorts.out.attach(out);
    const expects = [5, 1];
    const sends = [5, 1];

    out.on('data', (data) => {
      chai.expect(data).to.equal(expects.shift());
      if (expects.length) { return; }
      return done();
    });

    for (const data of Array.from(sends)) { ins.send(data); }
    return ins.disconnect();
  });

  return it('test sending to three outports', (done) => {
    const sends = [1, 2, 3, 4, 5, 6];
    const outs = [{
      socket: noflo.internalSocket.createSocket(),
      expects: [1, 4],
    },
    {
      socket: noflo.internalSocket.createSocket(),
      expects: [2, 5],
    },
    {
      socket: noflo.internalSocket.createSocket(),
      expects: [3, 6],
    },
    ];

    let disconnected = 0;
    outs.forEach((out) => {
      c.outPorts.out.attach(out.socket);

      out.socket.on('data', (data) => {
        chai.expect(out.expects.length).to.be.ok;
        return chai.expect(data).to.equal(out.expects.shift());
      });
      return out.socket.on('disconnect', () => {
        disconnected++;
        if (disconnected === outs.length) { return done(); }
      });
    });

    for (const send of Array.from(sends)) { ins.send(send); }
    return ins.disconnect();
  });
});
