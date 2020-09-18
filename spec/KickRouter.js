describe('KickRouter component', () => {
  let c = null;
  let next = null;
  let prev = null;
  let index = null;
  let ins = null;
  let outs = [];
  before(function (done) {
    this.timeout(4000);
    const loader = new noflo.ComponentLoader(baseDir);
    loader.load('routers/KickRouter', (err, instance) => {
      if (err) {
        done(err);
        return;
      }
      c = instance;
      ins = noflo.internalSocket.createSocket();
      next = noflo.internalSocket.createSocket();
      prev = noflo.internalSocket.createSocket();
      index = noflo.internalSocket.createSocket();
      c.inPorts.in.attach(ins);
      c.inPorts.next.attach(next);
      c.inPorts.prev.attach(prev);
      c.inPorts.index.attach(index);
      done();
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
    c.outPorts.out.attach(outs[3]);
  });
  afterEach((done) => {
    c.outPorts.out.detach(outs[0]);
    c.outPorts.out.detach(outs[1]);
    c.outPorts.out.detach(outs[2]);
    c.outPorts.out.detach(outs[3]);
    c.shutdown(done);
  });

  describe('receiving a next', () => it('should release a stream to next index', (done) => {
    const expected = [
      '1 < foo',
      '1 DATA a',
      '1 >',
      '2 DATA b',
    ];
    const received = [];
    outs.forEach((socket, idx) => {
      socket.on('begingroup', (group) => received.push(`${idx} < ${group}`));
      socket.on('data', (data) => {
        received.push(`${idx} DATA ${data}`);
        if (received.length !== expected.length) { return; }
        chai.expect(received).to.eql(expected);
        done();
      });
      socket.on('endgroup', () => {
        received.push(`${idx} >`);
        if (received.length !== expected.length) { return; }
        chai.expect(received).to.eql(expected);
        done();
      });
    });
    ins.beginGroup('foo');
    ins.send('a');
    ins.endGroup();
    next.send(null);
    ins.send('b');
    next.send(null);
  }));
  describe('receiving a prev', () => it('should release a stream to previous index', (done) => {
    const expected = [
      '3 < foo',
      '3 DATA a',
      '3 >',
      '2 DATA b',
    ];
    const received = [];
    outs.forEach((socket, idx) => {
      socket.on('begingroup', (group) => received.push(`${idx} < ${group}`));
      socket.on('data', (data) => {
        received.push(`${idx} DATA ${data}`);
        if (received.length !== expected.length) { return; }
        chai.expect(received).to.eql(expected);
        done();
      });
      socket.on('endgroup', () => {
        received.push(`${idx} >`);
        if (received.length !== expected.length) { return; }
        chai.expect(received).to.eql(expected);
        done();
      });
    });
    ins.beginGroup('foo');
    ins.send('a');
    ins.endGroup();
    prev.send(null);
    ins.send('b');
    prev.send(null);
  }));
  describe('receiving an index', () => it('should release a stream to given index', (done) => {
    const expected = [
      '0 < foo',
      '0 DATA a',
      '0 >',
      '2 DATA b',
    ];
    const received = [];
    outs.forEach((socket, idx) => {
      socket.on('begingroup', (group) => received.push(`${idx} < ${group}`));
      socket.on('data', (data) => {
        received.push(`${idx} DATA ${data}`);
        if (received.length !== expected.length) { return; }
        chai.expect(received).to.eql(expected);
        done();
      });
      socket.on('endgroup', () => {
        received.push(`${idx} >`);
        if (received.length !== expected.length) { return; }
        chai.expect(received).to.eql(expected);
        done();
      });
    });
    ins.beginGroup('foo');
    ins.send('a');
    ins.endGroup();
    index.send(0);
    ins.send('b');
    index.send(2);
  }));
});
