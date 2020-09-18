/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
describe('PacketRouter component', () => {
  let c = null;
  let ins = null;
  let outA = null;
  let outB = null;
  let outC = null;
  let missedOut = null;
  let loader = null;

  before(() => loader = new noflo.ComponentLoader(baseDir));
  beforeEach(function (done) {
    this.timeout(4000);
    return loader.load('routers/PacketRouter', (err, instance) => {
      if (err) { return done(err); }
      c = instance;
      ins = noflo.internalSocket.createSocket();
      outA = noflo.internalSocket.createSocket();
      outB = noflo.internalSocket.createSocket();
      outC = noflo.internalSocket.createSocket();
      missedOut = noflo.internalSocket.createSocket();
      c.inPorts.in.attach(ins);
      c.outPorts.missed.attach(missedOut);
      return done();
    });
  });

  describe('when instantiated', () => {
    it('should have an input port', () => chai.expect(c.inPorts.in).to.be.an('object'));
    return it('should have an output port', () => {
      chai.expect(c.outPorts.out).to.be.an('object');
      return chai.expect(c.outPorts.missed).to.be.an('object');
    });
  });

  return it('routes incoming IPs based on IP stream position', (done) => {
    c.outPorts.out.attach(outA);
    c.outPorts.out.attach(outB);

    const expected = [
      'a a',
      'b b',
      'missed c',
      'missed d',
    ];
    const received = [];

    outA.on('data', (data) => {
      received.push(`a ${data}`);
      if (received.length !== expected.length) { return; }
      chai.expect(received).to.eql(expected);
      return done();
    });

    outB.on('data', (data) => {
      received.push(`b ${data}`);
      if (received.length !== expected.length) { return; }
      chai.expect(received).to.eql(expected);
      return done();
    });

    missedOut.on('data', (data) => {
      received.push(`missed ${data}`);
      if (received.length !== expected.length) { return; }
      chai.expect(received).to.eql(expected);
      return done();
    });

    ins.beginGroup();
    ins.send('a');
    ins.send('b');
    ins.send('c');
    ins.send('d');
    return ins.endGroup();
  });
});
