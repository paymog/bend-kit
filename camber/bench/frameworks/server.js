import http from 'node:http';
import Fastify from 'fastify';

const [mode, profileText, portText] = process.argv.slice(2);
const profile = Number(profileText), port = Number(portText), limit = 8 * 1024 * 1024;
const textType = 'text/plain; charset=utf-8';
const registrations = new Map();
if (profile) for (let id = 0; id < profile; id++) registrations.set(`/route/${id}`, ['route', id]);
else for (const path of ['/text', '/json', '/decode', '/echo', '/hooks/0', '/hooks/1', '/hooks/5']) registrations.set(path, [path.slice(1)]);
function select(path) {
  return registrations.get(path) ?? (!profile && /^\/users\/[^/]+$/.test(path) ? ['user', path.slice(7)] : ['missing']);
}
function response(status, body, headers = {}) { return {status, body: typeof body === 'string' ? Buffer.from(body) : body, headers}; }
function text(status, body) { return response(status, body, {'content-type': textType}); }
function json(value, headers = {}) { return response(200, JSON.stringify(value), {'content-type': 'application/json', ...headers}); }
function business(job, method, headers, body) {
  const [op, parameter] = job;
  const get = method === 'GET' || method === 'HEAD';
  if (op === 'missing') return text(404, 'not found');
  if (op === 'echo' || op === 'decode') {
    if (method !== 'POST') return response(405, '', {allow: 'POST'});
    if (op === 'echo') return response(200, body, {'content-type': 'application/octet-stream'});
    if (headers['content-type'] !== 'application/json') return text(415, 'unsupported media type');
    try {
      const value = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(body));
      if (!value || Array.isArray(value) || Object.keys(value).length !== 1 || typeof value.name !== 'string' || value.name.length === 0) return text(400, 'invalid name');
      return json({name: value.name});
    } catch { return text(400, 'invalid name'); }
  }
  if (op === 'user') {
    if (!/^\d+$/.test(parameter) || Number(parameter) > 4294967295) return text(400, 'invalid id');
    if (!get) return response(405, '', {allow: 'GET, HEAD'});
    return json({id: Number(parameter)});
  }
  if (!get) return response(405, '', {allow: 'GET, HEAD'});
  if (op === 'text') return text(200, 'OK\n');
  if (op === 'json') return response(200, '{"ok":true}', {'content-type': 'application/json'});
  if (op === 'route') return json({id: parameter});
  const count = Number(op.slice(6));
  for (let i = 0; i < count; i++) if (headers.authorization !== 'Bearer alice') return response(401, '', {'www-authenticate': 'Bearer'});
  return response(200, '{"ok":true}', {'content-type': 'application/json', 'x-hook-count': String(count)});
}
if (mode === 'raw') {
  http.createServer(async (request, reply) => {
    let length = 0, chunks = [];
    for await (const chunk of request) {
      length += chunk.length;
      if (length > limit) { reply.writeHead(413, {'content-length': '0', connection: 'close'}); reply.end(); request.destroy(); return; }
      chunks.push(chunk);
    }
    const result = business(select(request.url), request.method, request.headers, Buffer.concat(chunks, length));
    reply.writeHead(result.status, {...result.headers, 'content-length': Buffer.byteLength(result.body)});
    reply.end(request.method === 'HEAD' ? undefined : result.body);
  }).listen(port, '127.0.0.1', () => console.log('READY'));
} else if (mode === 'framework') {
  const app = Fastify({logger: false, bodyLimit: limit, exposeHeadRoutes: false});
  app.removeAllContentTypeParsers();
  app.addContentTypeParser('*', {parseAs: 'buffer'}, (request, body, done) => done(null, body));
  const execute = job => async (request, reply) => {
    const selected = job[0] === 'user' ? ['user', request.params.id] : job;
    const result = business(selected, request.method, request.headers, request.body ?? Buffer.alloc(0));
    reply.code(result.status).headers({...result.headers, 'content-length': Buffer.byteLength(result.body)});
    return reply.send(request.method === 'HEAD' ? undefined : result.body);
  };
  for (const [path, job] of registrations) app.route({method: ['GET', 'HEAD', 'POST'], url: path, handler: execute(job)});
  if (!profile) app.route({method: ['GET', 'HEAD', 'POST'], url: '/users/:id', handler: execute(['user'])});
  app.setNotFoundHandler(execute(['missing']));
  await app.listen({port, host: '127.0.0.1'});
  console.log('READY');
} else throw Error('expected raw or framework');
