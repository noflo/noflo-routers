describe('SplitInSequence component', () => {
  let c = null;
  let ins = null;
  let out = null;
  let loader = null;

  before(() => {
    loader = new noflo.ComponentLoader(baseDir);
  });
  beforeEach(function (done) {
    this.timeout(4000);
    loader.load('routers/SplitInSequence', (err, instance) => {
      if (err) {
        done(err);
        return;
      }
      c = instance;
      ins = noflo.internalSocket.createSocket();
      c.inPorts.in.attach(ins);
      done();
    });
  });

  describe('when instantiated', () => {
    it('should have an input port', () => chai.expect(c.inPorts.in).to.be.an('object'));
    it('should have an output port', () => chai.expect(c.outPorts.out).to.be.an('object'));
  });

  it('test sending to single outport', (done) => {
    out = noflo.internalSocket.createSocket();
    c.outPorts.out.attach(out);
    const expects = [5, 1];
    const sends = [5, 1];

    out.on('data', (data) => {
      chai.expect(data).to.equal(expects.shift());
      if (expects.length) { return; }
      done();
    });

    sends.forEach((val) => ins.send(val));
    ins.disconnect();
  });

  it('test sending to three outports', (done) => {
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
    outs.forEach((outSocket) => {
      c.outPorts.out.attach(outSocket.socket);

      outSocket.socket.on('data', (data) => {
        chai.expect(outSocket.expects.length).to.be.above(0);
        chai.expect(data).to.equal(outSocket.expects.shift());
      });
      outSocket.socket.on('disconnect', () => {
        disconnected += 1;
        if (disconnected === outs.length) {
          done();
        }
      });
    });

    sends.forEach((val) => ins.send(val));
    ins.disconnect();
  });
});
