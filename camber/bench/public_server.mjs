import http from 'node:http';
import {performance} from 'node:perf_hooks';
const [kind, profileArg, portArg] = process.argv.slice(2);
const profile = Number(profileArg), port = Number(portArg), limit = 8388608;
const begin = performance.now();
const routes = profile ? Array.from({length: profile}, (_, n) => ['GET', `/route/${n}`, `route-${n}`]) : [['GET', '/text', 'text'], ['GET', '/json', 'json'], ['GET', '/users/:id', 'parameter'], ['POST', '/decode', 'decode'], ['POST', '/echo', 'echo'], ...[0,1,5].map(n => ['GET', `/hooks/${n}`, `hooks-${n}`])];
const output = (status, body, headers={}) => ({status, body: Buffer.isBuffer(body) ? body : Buffer.from(body), headers});
const text = (status, body) => output(status, body, {'content-type':'text/plain; charset=utf-8'});
const json = value => output(200, JSON.stringify(value), {'content-type':'application/json'});
function business(op, parameter, body, headers, count) {
  if(op==='text') return text(200,'OK\n');
  if(op==='json') return output(200,'{"ok":true}',{'content-type':'application/json'});
  if(op==='parameter') return /^\d+$/.test(parameter) && Number(parameter)<=4294967295 ? json({id:Number(parameter)}) : text(400,'invalid id');
  if(op.startsWith('route-')) return json({id:Number(op.slice(6))});
  if(op.startsWith('hooks-')) return output(200,'{"ok":true}',{'content-type':'application/json','x-hook-count':String(count)});
  if(op==='echo') return output(200,body,{'content-type':'application/octet-stream'});
  if(headers['content-type']!=='application/json') return text(415,'invalid name');
  try {
    const value=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(body));
    if(!value || Array.isArray(value) || Object.keys(value).length!==1 || typeof value.name!=='string' || [...value.name].length<1 || [...value.name].length>100) return text(400,'invalid name');
    return json({name:value.name});
  } catch { return text(400,'invalid name'); }
}
function hook(headers) { return headers.authorization==='Bearer alice'; }
const rejected=()=>output(401,'',{'www-authenticate':'Bearer'});
const missing=()=>text(404,'not found');
const method=verb=>output(405,'',{allow:verb==='GET'?'GET, HEAD, OPTIONS':'OPTIONS, POST'});
function resolve(path) {
  const hit=routes.find(r=>r[1]===path);
  return hit ?? (/^\/users\/[^/]+$/.test(path)?['GET','/users/:id','parameter']:null);
}
function execute(route, verb, parameter, body, headers, count) {
  if(!route) return missing();
  if(verb!==route[0] && !(route[0]==='GET' && verb==='HEAD')) return method(route[0]);
  return business(route[2],parameter,body,headers,count);
}
function send(reply, result, head=false) {
  reply.writeHead(result.status,{...result.headers,'content-length':result.body.length});
  reply.end(head?undefined:result.body);
}
let close;
if(kind==='node-http') {
  const server=http.createServer(async(req,res)=>{
    let length=0;const chunks=[];
    for await(const chunk of req) {length+=chunk.length;if(length>limit){send(res,output(413,''));return;}chunks.push(chunk);}
    const route=resolve(req.url);let count=0;
    if(route?.[2].startsWith('hooks-')) for(let n=0;n<Number(route[2].slice(6));n++){if(!hook(req.headers)){send(res,rejected());return;}count++;}
    send(res,execute(route,req.method,req.url.slice(7),Buffer.concat(chunks,length),req.headers,count),req.method==='HEAD');
  });
  server.maxConnections=32;server.headersTimeout=200;server.requestTimeout=30000;
  await new Promise(resolve=>server.listen(port,'127.0.0.1',resolve));close=()=>server.close();
} else if(kind==='fastify') {
  const {default:Fastify}=await import('fastify');const app=Fastify({logger:false,bodyLimit:limit,exposeHeadRoutes:false});
  app.removeAllContentTypeParsers();app.addContentTypeParser('*',{parseAs:'buffer'},(req,body,done)=>done(null,body));
  for(const route of routes) {
    const count=route[2].startsWith('hooks-')?Number(route[2].slice(6)):0;
    const hooks=Array.from({length:count},()=>async(req,reply)=>{if(!hook(req.headers)) {const r=rejected();reply.code(r.status).headers(r.headers).send(r.body);}else req.hookCount=(req.hookCount??0)+1;});
    app.route({url:route[1],method:['GET','HEAD','POST'],onRequest:hooks,handler:async(req,reply)=>{const r=execute(route,req.method,req.params.id,req.body??Buffer.alloc(0),req.headers,req.hookCount??0);return reply.code(r.status).headers({...r.headers,'content-length':r.body.length}).send(r.body);}});
  }
  app.setNotFoundHandler((req,reply)=>{const r=missing();return reply.code(r.status).headers(r.headers).send(r.body);});
  await app.listen({port,host:'127.0.0.1'});close=()=>app.close();
} else if(kind==='hono') {
  const {Hono}=await import('hono');const {serve}=await import('@hono/node-server');const app=new Hono({strict:true});
  for(const route of routes) {
    const count=route[2].startsWith('hooks-')?Number(route[2].slice(6)):0;
    const hooks=Array.from({length:count},()=>async(c,next)=>{if(!hook(Object.fromEntries(c.req.raw.headers))){const r=rejected();return new Response(r.body,{status:r.status,headers:r.headers});}c.set('hooks',(c.get('hooks')??0)+1);await next();});
    app.all(route[1],...hooks,async c=>{const body=Buffer.from(await c.req.arrayBuffer());if(body.length>limit)return new Response(null,{status:413});const r=execute(route,c.req.method,c.req.param('id'),body,Object.fromEntries(c.req.raw.headers),c.get('hooks')??0);return new Response(r.body,{status:r.status,headers:{...r.headers,'content-length':String(r.body.length)}});});
  }
  app.notFound(()=>{const r=missing();return new Response(r.body,{status:r.status,headers:r.headers});});
  const server=serve({fetch:app.fetch,port,hostname:'127.0.0.1'});close=()=>server.close();
} else if(kind==='elysia') {
  const {Elysia}=await import('elysia');let app=new Elysia({sucrose:{gcTime:0}});
  for(const route of routes) {
    const count=route[2].startsWith('hooks-')?Number(route[2].slice(6)):0;
    app=app.all(route[1],({request,params,body})=>{const r=execute(route,request.method,params?.id,Buffer.from(body??new ArrayBuffer(0)),Object.fromEntries(request.headers),count);return new Response(r.body,{status:r.status,headers:{...r.headers,'content-length':String(r.body.length)}});},{parse:async({request})=>request.arrayBuffer(),beforeHandle:Array.from({length:count},()=>({request})=>{if(!hook(Object.fromEntries(request.headers))){const r=rejected();return new Response(r.body,{status:r.status,headers:r.headers});}})});
  }
  app=app.onError(({code})=>{if(code==='NOT_FOUND'){const r=missing();return new Response(r.body,{status:r.status,headers:r.headers});}}).listen({port,hostname:'127.0.0.1',maxRequestBodySize:limit});close=()=>app.stop();
} else throw Error('unknown comparator');
console.log('CONSTRUCTION_MS '+(performance.now()-begin));console.log('READY');
process.on('SIGTERM',async()=>{await close();console.log('JOINED');});
