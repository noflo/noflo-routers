/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const noflo = require('noflo');

exports.getComponent = function () {
  const c = new noflo.Component();
  c.description = 'Switch output to new connection every time "next" is sent';
  c.inPorts.add('in',
    { datatype: 'all' });
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
    if (input.hasData('next')) {
      input.getData('next');
      if (!c.current[input.scope]) {
        c.current[input.scope] = 0;
      }
      c.current[input.scope]++;
      if (c.current[input.scope] >= c.outPorts.out.listAttached().length) {
        c.current[input.scope] = 0;
      }
      output.done();
      return;
    }
    if (!input.has('in')) { return; }
    if (!c.current[input.scope]) {
      c.current[input.scope] = 0;
    }
    const packet = input.get('in');
    const attached = c.outPorts.out.listAttached();
    packet.index = attached[c.current[input.scope]];
    return output.sendDone({ out: packet });
  });
};
