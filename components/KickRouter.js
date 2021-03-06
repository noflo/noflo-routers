const noflo = require('noflo');

exports.getComponent = () => {
  const c = new noflo.Component();
  c.description = 'Releases a stream to a specified index on prev/next/index';
  c.inPorts.add('in',
    { datatype: 'all' });
  c.inPorts.add('index',
    { datatype: 'int' });
  c.inPorts.add('prev',
    { datatype: 'bang' });
  c.inPorts.add('next',
    { datatype: 'bang' });
  c.outPorts.add('out', {
    datatype: 'all',
    addressable: true,
  });
  c.current = {};
  c.tearDown = function (callback) {
    c.current = {};
    return callback();
  };
  c.forwardBrackets = {};
  return c.process((input, output) => {
    if (!input.hasStream('in')) { return; }
    if (!c.current[input.scope]) {
      c.current[input.scope] = 0;
    }

    const sendToIndex = function () {
      const stream = input.getStream('in');
      const attached = c.outPorts.out.listAttached();
      const idx = attached[c.current[input.scope]];
      return (() => {
        const result = [];
        stream.forEach((packet) => {
          const ip = packet;
          ip.index = idx;
          result.push(output.send({ out: ip }));
        });
        return result;
      })();
    };

    if (input.hasData('next')) {
      input.getData('next');
      c.current[input.scope] += 1;
      if (c.current[input.scope] >= c.outPorts.out.listAttached().length) {
        c.current[input.scope] = 0;
      }
      sendToIndex();
      output.done();
      return;
    }
    if (input.hasData('prev')) {
      input.getData('prev');
      c.current[input.scope] -= 1;
      if (c.current[input.scope] < 0) {
        c.current[input.scope] = c.outPorts.out.listAttached().length - 1;
      }
      sendToIndex();
      output.done();
      return;
    }
    if (input.hasData('index')) {
      c.current[input.scope] = parseInt(input.getData('index'), 10);
      sendToIndex();
      output.done();
    }
  });
};
