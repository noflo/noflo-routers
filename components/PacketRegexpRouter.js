/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const noflo = require('noflo');

exports.getComponent = function () {
  const c = new noflo.Component();
  c.description = 'Route IPs based on RegExp match on the IP content (strings \
only). The position of the RegExp determines which port to forward to.';
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
    let idx;
    if (!input.hasData('in', 'route')) { return; }
    const routes = input.getData('route');
    if (!Array.isArray(routes)) {
      output.done(new Error('Route must be an array'));
      return;
    }
    const regexps = [];
    for (const route of Array.from(routes)) {
      if (typeof route === 'string') {
        regexps.push(new RegExp(route));
        continue;
      }
      if (route instanceof RegExp) {
        regexps.push(route);
        continue;
      }
      output.done(new Error('Route array can only contain strings or RegExps'));
      return;
    }

    const data = input.getData('in');
    if (typeof data !== 'string') {
      output.done(new Error('PacketRegexpRouter can only route strings'));
      return;
    }
    const matchedIndexes = [];
    for (idx = 0; idx < regexps.length; idx++) {
      const regexp = regexps[idx];
      if (data.match(regexp)) { matchedIndexes.push(idx); }
    }
    if (!matchedIndexes.length) {
      output.sendDone({ missed: data });
      return;
    }
    for (idx of Array.from(matchedIndexes)) {
      output.send({
        out: new noflo.IP('data', data,
          { index: idx }),
      });
    }
    output.done();
  });
};
