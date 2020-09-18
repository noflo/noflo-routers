const noflo = require('noflo');

exports.getComponent = function () {
  const c = new noflo.Component();
  c.description = 'Route IPs based on RegExp match on the IP content (strings only). The position of the RegExp determines which port to forward to.';
  c.inPorts.add('in',
    { datatype: 'string' });
  c.inPorts.add('route', {
    datatype: 'array',
    control: true,
  });
  c.outPorts.add('out', {
    datatype: 'string',
    addressable: true,
  });
  c.outPorts.add('missed',
    { datatype: 'all' });
  c.outPorts.add('error',
    { datatype: 'object' });
  c.forwardBrackets = { in: ['out', 'missed'] };
  return c.process((input, output) => {
    if (!input.hasData('in', 'route')) { return; }
    const routes = input.getData('route');
    if (!Array.isArray(routes)) {
      output.done(new Error('Route must be an array'));
      return;
    }
    const regexps = [];
    let errored;
    routes.forEach((route) => {
      if (typeof route === 'string') {
        regexps.push(new RegExp(route));
        return;
      }
      if (route instanceof RegExp) {
        regexps.push(route);
        return;
      }
      errored = new Error('Route array can only contain strings or RegExps');
    });
    if (errored) {
      output.done(errored);
      return;
    }

    const data = input.getData('in');
    if (typeof data !== 'string') {
      output.done(new Error('PacketRegexpRouter can only route strings'));
      return;
    }
    const matchedIndexes = [];
    for (let idx = 0; idx < regexps.length; idx += 1) {
      const regexp = regexps[idx];
      if (data.match(regexp)) { matchedIndexes.push(idx); }
    }
    if (!matchedIndexes.length) {
      output.sendDone({ missed: data });
      return;
    }
    matchedIndexes.forEach((idx) => {
      output.send({
        out: new noflo.IP('data', data,
          { index: idx }),
      });
    });
    output.done();
  });
};
