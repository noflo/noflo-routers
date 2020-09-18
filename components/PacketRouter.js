/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const noflo = require('noflo');

exports.getComponent = function () {
  const c = new noflo.Component();
  c.description = 'Routes IPs based on position in an incoming IP stream';
  c.inPorts.add('in', {
    datatype: 'all',
    addressable: true,
  });
  c.outPorts.add('out', {
    datatype: 'all',
    addressable: true,
  });
  c.outPorts.add('missed',
    { datatype: 'all' });
  c.outPorts.add('error');
  c.forwardBrackets = {};
  return c.process((input, output) => {
    const indexesWithStreams = input.attached('in').filter((idx) => input.hasStream(['in', idx]));
    if (!indexesWithStreams.length) { return; }
    indexesWithStreams.forEach((idx) => {
      const stream = input.getStream(['in', idx]);
      if ((stream[0].type === 'openBracket') && (stream[0].data === null)) {
        // Remove the surrounding brackets if they're unnamed
        const before = stream.shift();
        const after = stream.pop();
      }
      let position = 0;
      const brackets = [];
      let hadData = false;
      return (() => {
        const result = [];
        for (const packet of Array.from(stream)) {
          if (packet.type === 'openBracket') {
            if (hadData && !brackets.length) {
              // Start of a new substream
              position++;
            }
            brackets.push(packet.data);
          }
          if (packet.type === 'closeBracket') {
            brackets.pop();
          }

          const attached = c.outPorts.out.listAttached();
          if (attached.indexOf(position) === -1) {
            output.send({ missed: packet });
            continue;
          }

          packet.index = position;
          output.send({ out: packet });

          if (packet.type === 'data') {
            if (hadData && brackets.length) {
              // Was already advanced by openBracket
              continue;
            }
            position++;
            result.push(hadData = true);
          } else {
            result.push(undefined);
          }
        }
        return result;
      })();
    });
    output.done();
  });
};
