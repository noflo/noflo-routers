const noflo = require('noflo');

exports.getComponent = () => {
  const c = new noflo.Component();
  c.description = 'Send each packet to one outport connection in sequence';
  c.inPorts.add('in',
    { datatype: 'all' });
  c.outPorts.add('out', {
    datatype: 'all',
    addressable: true,
  });
  c.current = 0;
  c.tearDown = function (callback) {
    c.current = 0;
    return callback();
  };
  return c.process((input, output) => {
    if (!input.hasData('in')) { return; }
    const packet = new noflo.IP('data', input.getData('in'));
    const attached = c.outPorts.out.listAttached();
    packet.index = attached[c.current];
    output.send({ out: packet });
    c.current += 1;
    if (c.current >= c.outPorts.out.listAttached().length) {
      c.current = 0;
    }
    output.done();
  });
};
