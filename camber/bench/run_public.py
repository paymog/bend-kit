"""Source-bound complete-application benchmarks. Requires coordinator's exclusive slot."""
import argparse
import asyncio
import contextlib
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import socket
import statistics
import subprocess
import tempfile
import threading
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CRITERIA = json.loads((HERE / 'public_criteria.json').read_text())
BUDGET = json.loads((ROOT / 'camber/raw_budget.json').read_text())
ENV = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')


def sources():
    paths = [HERE / name for name in ('run_public.py', 'public_app.bend', 'public_main.bend', 'public_direct.bend', 'public_server.mjs', 'public_libevent.c', 'public_flask.py', 'public_package.json', 'public_requirements.txt', 'public_criteria.json')]
    paths += list((HERE / 'public_axum').rglob('*.rs')) + list((HERE / 'public_axum').glob('Cargo.*'))
    paths += [ROOT / 'camber/raw_budget.json']
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def fixtures():
    rows = [('text', 0, 'GET', '/text', b'', 200, b'OK\n', {'content-type': 'text/plain; charset=utf-8'}),
            ('json', 0, 'GET', '/json', b'', 200, b'{"ok":true}', {'content-type': 'application/json'}),
            ('parameter', 0, 'GET', '/users/7', b'', 200, b'{"id":7}', {'content-type': 'application/json'}),
            ('json-1k', 0, 'POST', '/decode', b'{"name":"Cara"}' + b' ' * 1009, 200, b'{"name":"Cara"}', {'content-type': 'application/json'})]
    for n in (0, 1, 5):
        rows.append((f'hooks-{n}', 0, 'GET', f'/hooks/{n}', b'', 200, b'{"ok":true}', {'content-type': 'application/json', 'x-hook-count': str(n)}))
    for n in (10, 100, 1000):
        rows += [(f'hit-{n}', n, 'GET', f'/route/{n-1}', b'', 200, f'{{"id":{n-1}}}'.encode(), {'content-type': 'application/json'}),
                 (f'miss-{n}', n, 'GET', f'/route/{n}', b'', 404, b'not found', {'content-type': 'text/plain; charset=utf-8'}),
                 (f'method-{n}', n, 'POST', f'/route/{n-1}', b'', 405, b'', {'allow': 'GET, HEAD, OPTIONS'})]
    for size, label in ((65536, '64k'), (4194304, '4m')):
        body = b'\x7f\x80\x00\xff' * (size // 4)
        rows.append((f'echo-{label}', 0, 'POST', '/echo', body, 200, body, {'content-type': 'application/octet-stream'}))
    return rows


HISTORY = {}


def save(path, data):
    key=str(path.resolve())
    if key not in HISTORY:
        previous=json.loads(path.read_text()) if path.exists() else {}
        HISTORY[key]=previous.get('attempts',[previous] if previous else [])
    attempts=HISTORY[key]
    if attempts and attempts[-1].get('attempt_id')==data['attempt_id']:
        attempts[-1]=data
    else:
        attempts.append(data)
    temporary=path.with_name(path.name+f'.{os.getpid()}.tmp')
    try:
        with temporary.open('w') as output:
            json.dump({'attempts':attempts},output,indent=2);output.write('\n')
            output.flush();os.fsync(output.fileno())
        os.replace(temporary,path)
    finally:
        if temporary.exists(): temporary.unlink()


def processes():
    if shutil.disk_usage(ROOT).free<10*1024**3:
        raise RuntimeError('disk headroom <10 GiB before process observation')
    output=subprocess.check_output(['ps','-axo','pid=,ppid=,rss=,time=,lstart='],text=True,timeout=5)
    table={}
    for line in output.splitlines():
        pid,parent,rss,cpu,identity=line.split(None,4)
        seconds=0.
        for part in cpu.replace('-',':').split(':'):
            seconds=seconds*60+float(part)
        table[int(pid)]={'ppid':int(parent),'rss_kib':int(rss),'cpu_seconds':seconds,'start_identity':identity}
    return table


def descendants(table, roots):
    selected=set(roots)
    while True:
        added={pid for pid,row in table.items() if row['ppid'] in selected}-selected
        if not added: return selected
        selected|=added


class Guard:
    """Aggregate actual root trees; retain PID-start identities through cleanup."""
    def __init__(self,data,output):
        self.data,self.output=data,output
        self.roots={}
        self.observed={}
        self.forced=set()
        self.peak_kib=0
        self.samples=[]
        self.failure=None
        self.cleanup_errors=[]
        self.servers={}
        self.lock=threading.RLock()
        self.stop=threading.Event()
        self.thread=threading.Thread(target=self.watch,daemon=True)
        self.thread.start()

    def track(self,process):
        with self.lock:
            self.roots[process.pid]=process
            self.observed[process.pid]={}
        self.sample()

    def sample(self):
        table=processes()
        with self.lock:
            roots=dict(self.roots)
            for root in roots: self.observe(root,table)
            known={pid for observed in self.observed.values() for pid,identity in observed.items()
                   if pid in table and table[pid]['start_identity']==identity}
            selected=descendants(table,{os.getpid(),*known})
            total=sum(table[p]['rss_kib'] for p in selected if p in table)
            self.peak_kib=max(self.peak_kib,total)
            self.samples.append({'host_monotonic':time.monotonic(),'aggregate_rss_kib':total,
                                 'processes':{str(p):table[p] for p in selected if p in table}})
        if total>20*1024**2:
            raise RuntimeError('aggregate root/descendant RSS >20 GiB')
        return table

    def watch(self):
        while not self.stop.wait(.1):
            try: self.sample()
            except BaseException as error:
                self.failure=str(error)
                self.kill()
                return

    def observe(self,root,table):
        observed=self.observed.setdefault(root,{})
        seeds={pid for pid,identity in observed.items()
               if pid in table and table[pid]['start_identity']==identity}
        process=self.roots.get(root)
        if process is not None and process.poll() is None and root in table: seeds.add(root)
        for pid in descendants(table,seeds) & table.keys():
            observed[pid]=table[pid]['start_identity']
        return {pid:identity for pid,identity in observed.items()
                if pid in table and table[pid]['start_identity']==identity}

    def surviving(self,root):
        table=processes()
        with self.lock: return self.observe(root,table)

    def kill(self,root=None):
        with self.lock:
            roots={p:v for p,v in self.roots.items() if root is None or p==root}
        for pid,process in roots.items():
            self.forced.add(pid)
            try:
                # Re-observe identities before signaling known descendants.
                survivors=self.surviving(pid)
                for child in sorted(survivors,reverse=True):
                    if child!=pid:
                        with contextlib.suppress(ProcessLookupError): os.kill(child,signal.SIGKILL)
            except BaseException as error:
                self.cleanup_errors.append(str(error))
            # Every root starts its own session; kill inherited helpers before reaping.
            if process.poll() is None:
                with contextlib.suppress(ProcessLookupError): os.killpg(process.pid,signal.SIGKILL)

    def release(self,process):
        root=process.pid;survivors={};observation_error=None
        try: process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.kill(root)
            try: process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                observation_error='root not reaped after forced cleanup deadline'
                self.cleanup_errors.append(observation_error)
        try:
            survivors=self.surviving(root)
            if survivors:
                self.kill(root)
                deadline=time.monotonic()+5
                while survivors and time.monotonic()<deadline:
                    time.sleep(.05);survivors=self.surviving(root)
        except BaseException as error:
            observation_error=str(error)
            self.cleanup_errors.append(observation_error)
        with self.lock:
            observed=dict(self.observed.get(root,{}))
            if process.returncode is not None and not survivors and observation_error is None:
                self.roots.pop(root,None)
        return {'pid':root,'exit':process.returncode,'root_reaped':process.returncode is not None,
                'observed_process_identities':observed,'surviving_observed_processes':survivors,
                'release_observation_error':observation_error,
                'observed_descendants_released':not survivors and observation_error is None,
                'forced':root in self.forced}

    def check(self):
        if self.failure: raise RuntimeError(self.failure)

    def close(self):
        self.stop.set()
        try: self.thread.join()
        except BaseException as error: self.cleanup_errors.append('monitor join: '+repr(error))
        # Each owner is attempted even if an earlier receipt cannot be saved.
        for server in list(self.servers.values()):
            try: self.kill(server.process.pid)
            except BaseException as error: self.cleanup_errors.append('server kill: '+repr(error))
            try: self.data['release'].append(server.finish('cleanup after interrupted/failed scenario'))
            except BaseException as error: self.cleanup_errors.append('server finish: '+repr(error))
        with self.lock: remaining=list(self.roots.values())
        for process in remaining:
            try: self.kill(process.pid)
            except BaseException as error: self.cleanup_errors.append('root kill: '+repr(error))
            try:
                receipt=self.release(process)
                self.data['release'].append({'cleanup_after_failure':True,**receipt})
            except BaseException as error: self.cleanup_errors.append('root release: '+repr(error))
        # A failed release may have prevented its reader/listener finalization.
        for server in list(self.servers.values()):
            try: self.data['release'].append(server.finish('finalize after root cleanup'))
            except BaseException as error: self.cleanup_errors.append('server finalization: '+repr(error))


def command(guard,argv,timeout=300,env=None):
    start=time.monotonic();sample_start=len(guard.samples)
    process=None;error=None;release={};output=''
    receipt={'command':list(map(str,argv)),'cwd':str(ROOT),'invoked_monotonic':start,
             'timeout_seconds':timeout,'state':'pre-start','pid':None,
             'source_sha256':dict(guard.data['source_sha256'])}
    guard.data['commands'].append(receipt);save(guard.output,guard.data)
    with tempfile.TemporaryFile(mode='w+t') as out:
        try:
            guard.check()
            if shutil.disk_usage(ROOT).free<10*1024**3: raise RuntimeError('disk headroom before command')
            process=subprocess.Popen(argv,cwd=ROOT,env=env or ENV,stdout=out,stderr=subprocess.STDOUT,start_new_session=True)
            receipt.update({'state':'running','pid':process.pid})
            guard.track(process);save(guard.output,guard.data)
            while process.poll() is None:
                guard.check()
                if time.monotonic()-start>timeout: raise RuntimeError('command deadline')
                time.sleep(.1)
        except BaseException as caught:
            error=repr(caught)
            if process is not None:
                try: guard.kill(process.pid)
                except BaseException as cleanup: guard.cleanup_errors.append('command kill: '+repr(cleanup))
        finally:
            if process is not None:
                try: release=guard.release(process)
                except BaseException as cleanup:
                    guard.cleanup_errors.append('command release: '+repr(cleanup))
                    error=error or repr(cleanup)
            try: out.seek(0);output=out.read()
            except BaseException as read_error: error=error or repr(read_error)
            snapshots=guard.samples[sample_start:]
            own=[s['processes'].get(str(process.pid),{}) for s in snapshots] if process else []
            receipt.update({'state':'finished','seconds':time.monotonic()-start,
                'output':output,'error':error,**release,
                'sampled_root_peak_rss_kib':max((s.get('rss_kib',0) for s in own),default=0),
                'sampled_root_cpu_seconds':max((s.get('cpu_seconds',0) for s in own),default=0),
                'sampled_aggregate_peak_rss_kib':max((s['aggregate_rss_kib'] for s in snapshots),default=0)})
            save(guard.output,guard.data)
    if error or release.get('exit')!=0 or release.get('forced') or not release.get('observed_descendants_released'):
        raise RuntimeError(json.dumps(receipt))
    return receipt


def freeport():
    with socket.socket() as peer:
        peer.bind(('127.0.0.1',0));return peer.getsockname()[1]


def rebound(port):
    try:
        with socket.socket() as peer:
            peer.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
            peer.bind(('127.0.0.1',port));peer.listen(1)
        return {'port':port,'rebind_and_listener_release':True}
    except OSError as error:
        return {'port':port,'rebind_and_listener_release':False,'error':str(error)}


class Server:
    def __init__(self,guard,argv,port,control=None,env=None,name=''):
        guard.check()
        if shutil.disk_usage(ROOT).free<10*1024**3: raise RuntimeError('disk headroom before server')
        self.guard,self.port,self.control,self.name=guard,port,control,name
        self.start=time.monotonic();self.lines=[];self.forced=False
        self.argv=list(map(str,argv));self.reader=None
        self.process=subprocess.Popen(argv,cwd=ROOT,env=env or ENV,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1,start_new_session=True)
        guard.servers[self.process.pid]=self
        guard.track(self.process)
        self.reader=threading.Thread(target=self.read,daemon=True);self.reader.start()

    def read(self):
        for line in self.process.stdout:
            self.lines.append({'host_receipt_monotonic':time.monotonic(),'text':line.rstrip()})

    async def ready(self):
        while time.monotonic()-self.start<30:
            self.guard.check()
            if self.process.poll() is not None: raise RuntimeError(str(self.lines))
            if any(r['text']=='READY' for r in self.lines):
                try:
                    connection=await Peer.open(self.port);await connection.close()
                    return time.monotonic()-self.start
                except OSError: pass
            await asyncio.sleep(.05)
        raise RuntimeError('readiness deadline')

    def metrics(self):
        row=self.guard.sample().get(self.process.pid,{})
        return {'rss_kib':row.get('rss_kib',0),'cpu_seconds':row.get('cpu_seconds',0)}

    async def close(self):
        error=None
        if self.process.poll() is None:
            try:
                if self.guard.failure: raise RuntimeError(self.guard.failure)
                if self.control:
                    peer=await Peer.open(self.control)
                    try: await peer.request('POST','/finish',b'')
                    finally: await peer.close()
                else:
                    self.process.send_signal(signal.SIGINT if self.name in ('axum','flask') else signal.SIGTERM)
                deadline=time.monotonic()+10
                while self.process.poll() is None and time.monotonic()<deadline: await asyncio.sleep(.05)
                if self.process.poll() is None: raise RuntimeError('shutdown deadline')
            except BaseException as caught:
                error=str(caught);self.guard.kill(self.process.pid)
        return self.finish(error)

    def finish(self,error=None):
        release={'pid':self.process.pid,'exit':self.process.returncode,'root_reaped':self.process.returncode is not None,
                 'observed_descendants_released':False,'forced':self.process.pid in self.guard.forced}
        try: release=self.guard.release(self.process)
        except BaseException as caught:
            self.guard.cleanup_errors.append('server release: '+repr(caught));error=error or repr(caught)
        reader_released=False;stdout_released=False
        try:
            if self.reader is not None and self.reader.ident is not None: self.reader.join(timeout=5)
            reader_released=self.reader is None or not self.reader.is_alive()
        except BaseException as caught:
            self.guard.cleanup_errors.append('reader join: '+repr(caught));error=error or repr(caught)
        if reader_released:
            try: self.process.stdout.close();stdout_released=True
            except BaseException as caught:
                self.guard.cleanup_errors.append('stdout close: '+repr(caught));error=error or repr(caught)
        listeners=[]
        for port in (self.port,self.control):
            if port is None: continue
            try: listeners.append(rebound(port))
            except BaseException as caught:
                listeners.append({'port':port,'rebind_and_listener_release':False,'error':repr(caught)})
                self.guard.cleanup_errors.append('listener observation: '+repr(caught));error=error or repr(caught)
        released=release['root_reaped'] and release['observed_descendants_released'] and reader_released and stdout_released and all(r['rebind_and_listener_release'] for r in listeners)
        receipt={'command':self.argv,'source_sha256':dict(self.guard.data['source_sha256']),
                 **release,'error':error,'logs':self.lines,'reader_released':reader_released,
                 'stdout_released':stdout_released,'listener_release':listeners,'released':released,
                 'verdict':'PASS' if released and not release['forced'] and release['exit']==0 and not error else 'FAIL/INCONCLUSIVE'}
        self.guard.data['server_commands'].append(receipt)
        if released: self.guard.servers.pop(self.process.pid,None)
        save(self.guard.output,self.guard.data)
        return receipt


class Peer:
    def __init__(self, reader, writer): self.reader, self.writer = reader, writer
    @classmethod
    async def open(cls, port):
        reader, writer = await asyncio.wait_for(asyncio.open_connection('127.0.0.1', port), 5)
        return cls(reader, writer)
    async def request(self, method, path, body, authorization='Bearer alice', work_id=None):
        media = 'application/octet-stream' if path == '/echo' else 'application/json'
        identifier=f'X-Work-Id: {work_id}\r\n' if work_id is not None else ''
        self.writer.write(f'{method} {path} HTTP/1.1\r\nHost: localhost\r\nConnection: keep-alive\r\nAuthorization: {authorization}\r\nContent-Type: {media}\r\n{identifier}Content-Length: {len(body)}\r\n\r\n'.encode()+body)
        await self.writer.drain()
        head = await asyncio.wait_for(self.reader.readuntil(b'\r\n\r\n'), 120)
        lines = head.decode('latin1').split('\r\n'); status = int(lines[0].split()[1]); headers = {}
        for line in lines[1:]:
            if line:
                key,value = line.split(':',1); headers[key.lower()] = value.strip()
        if 'transfer-encoding' in headers: raise AssertionError('fixture requires known-length body')
        length = int(headers.get('content-length','0'))
        payload = await asyncio.wait_for(self.reader.readexactly(length), 120)
        return status, headers, payload
    async def close(self):
        self.writer.close()
        with contextlib.suppress(OSError): await self.writer.wait_closed()


def parity(response, row):
    status, headers, body = response
    if status != row[5] or body != row[6] or any(headers.get(k) != v for k,v in row[7].items()):
        raise AssertionError({'workload':row[0], 'status':status, 'headers':headers, 'body_sha256':hashlib.sha256(body).hexdigest(), 'expected_sha256':hashlib.sha256(row[6]).hexdigest()})
    if int(headers['content-length']) != len(body): raise AssertionError('bad framing length')
    return hashlib.sha256(body).hexdigest()


def percentiles(values):
    if not values: return {'p50_ms':None, 'p95_ms':None, 'p99_ms':None}
    ordered=sorted(values)
    return {f'p{n}_ms': ordered[min(len(ordered)-1, int((len(ordered)-1)*n/100))]*1000 for n in (50,95,99)}


async def load(server, row, duration, concurrency, rate=None, allow_overload=False, offering_finished=None):
    """Bounded client queues; every received response checks full bytes and headers."""
    before=server.metrics();start=time.monotonic();queue=asyncio.Queue(maxsize=concurrency*2)
    latencies=[];errors=[];statuses={};successes=0;missed=0;checksums={};issued=0;within_window=0
    last_offer=None;offer_end=None
    async def worker():
        nonlocal successes,within_window
        peer=None
        try:
            while True:
                scheduled=await queue.get()
                if scheduled is None: break
                try:
                    server.guard.check()
                    if peer is None: peer=await Peer.open(server.port)
                    response=await peer.request(row[2],row[3],row[4])
                    status=response[0];statuses[str(status)]=statuses.get(str(status),0)+1
                    if allow_overload and status==503:
                        if response[2]: raise AssertionError('capacity response unexpectedly has body')
                    else:
                        checksum=parity(response,row);checksums[checksum]=checksums.get(checksum,0)+1;successes+=1
                        if time.monotonic()-start<=duration: within_window+=1
                    latencies.append(time.monotonic()-scheduled)
                    if response[1].get('connection','').lower()=='close': await peer.close();peer=None
                except Exception as error:
                    errors.append(str(error))
                    if peer: await peer.close();peer=None
        finally:
            if peer: await peer.close()
    workers=[asyncio.create_task(worker()) for _ in range(concurrency)]
    try:
        while time.monotonic()-start<duration:
            scheduled=start+issued/rate if rate else time.monotonic()
            if rate and scheduled>time.monotonic(): await asyncio.sleep(scheduled-time.monotonic())
            if time.monotonic()-start>=duration: break
            if rate:
                try: queue.put_nowait(scheduled)
                except asyncio.QueueFull: missed+=1
            else: await queue.put(scheduled)
            last_offer=time.monotonic();issued+=1
            if issued%100==0: await asyncio.sleep(0)
        offer_end=time.monotonic()
        if offering_finished is not None and not offering_finished.done():
            offering_finished.set_result({'offering_finished_monotonic':offer_end,'last_offer_monotonic':last_offer})
        for _ in workers: await queue.put(None)
        outcomes=await asyncio.gather(*workers,return_exceptions=True)
        for outcome in outcomes:
            if isinstance(outcome,BaseException): errors.append('worker lifecycle: '+repr(outcome))
    except BaseException as abort:
        aborted=time.monotonic()
        if offering_finished is not None and not offering_finished.done(): offering_finished.set_exception(abort)
        for task in workers:
            if not task.done(): task.cancel()
        outcomes=await asyncio.gather(*workers,return_exceptions=True)
        server.guard.data.setdefault('client_load_aborts',[]).append({
            'abort':repr(abort),'aborted_monotonic':aborted,'last_offer_monotonic':last_offer,
            'offering_finished_monotonic':offer_end,'queued_offers_remaining':queue.qsize(),
            'owned_workers':len(workers),'all_owned_workers_joined':all(task.done() for task in workers),
            'worker_lifecycle_exceptions':[repr(outcome) for outcome in outcomes if isinstance(outcome,BaseException)],
            'verdict':'FAIL/INCONCLUSIVE'})
        raise
    finished=time.monotonic();elapsed=finished-start;after=server.metrics()
    return {'offered_rate':rate,'seconds':elapsed,'load_seconds':duration,'concurrency':concurrency,'issued':issued,'successful_responses':successes,
            'measurement_started_monotonic':start,'measurement_finished_monotonic':finished,
            'requested_offering_finish_monotonic':start+duration,'offering_finished_monotonic':offer_end,
            'last_offer_monotonic':last_offer,'offering_finish_lateness_seconds':max(0,offer_end-start-duration),
            'successful_responses_within_offered_window':within_window,'drain_successes':successes-within_window,
            'responses_per_second':successes/elapsed,'throughput_interval':'actual first-offer to final response, including drain',
            'status_distribution':statuses,'errors':errors,'generator_queue_drops':missed,
            'body_sha256_counts':checksums,'latency_includes_scheduled_delay':rate is not None,**percentiles(latencies),
            'server_cpu_seconds':after['cpu_seconds']-before['cpu_seconds'],'server_rss_before_kib':before['rss_kib'],'server_rss_after_kib':after['rss_kib'],
            'verdict':'PASS' if not errors and not missed and successes else 'FAIL/INCONCLUSIVE'}


def versions(guard):
    return {name:command(guard,argv,30)['output'].strip() for name,argv in {'bend':['bend','version'],'bun':['bun','--version'],'node':['node','--version'],'rust':['rustc','--version'],'python':['python3','--version'],'libevent':['pkg-config','--modversion','libevent'],'json-c':['pkg-config','--modversion','json-c']}.items()}


def prepare(guard,temp,data):
    for entry,name in [('public_main.bend','server'),('public_direct.bend','direct')]:
        for suffix in ('','js'):
            target=temp/(name+('.js' if suffix else ''))
            receipt=command(guard,['bend',str(HERE/entry),'-o',str(target)],300)
            receipt['artifact_bytes']=target.stat().st_size;receipt['artifact_sha256']=hashlib.sha256(target.read_bytes()).hexdigest()
            data['build'][name+('-js' if suffix else '-native')]=receipt
    flags=command(guard,['pkg-config','--cflags','--libs','libevent','json-c'],30)['output'].split()
    data['build']['libevent']=command(guard,['cc','-O3',str(HERE/'public_libevent.c'),'-o',str(temp/'libevent'),*flags],120)
    data['build']['axum']=command(guard,['cargo','build','--release','--manifest-path',str(HERE/'public_axum/Cargo.toml'),'--target-dir',str(temp/'rust')],600)
    shutil.copyfile(HERE/'public_package.json',temp/'package.json');shutil.copyfile(HERE/'public_server.mjs',temp/'public_server.mjs')
    data['build']['js-install']=command(guard,['bun','install','--cwd',str(temp)],180)
    data['build']['python-venv']=command(guard,['uv','venv',str(temp/'venv')],60)
    data['build']['python-install']=command(guard,['uv','pip','install','--python',str(temp/'venv/bin/python'),'-r',str(HERE/'public_requirements.txt')],180)
    for name,path in [('libevent',temp/'libevent'),('axum',temp/'rust/release/camber-public-axum')]:
        data['build'][name]['artifact_bytes']=path.stat().st_size
        data['build'][name]['artifact_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
    for name in ('bun.lock','package.json'):
        path=temp/name
        if path.exists(): data.setdefault('dependency_artifacts',{})[name]=path.read_text()
    data.setdefault('dependency_artifacts',{})['Cargo.lock']=(HERE/'public_axum/Cargo.lock').read_text()
    data['dependency_artifacts']['python-freeze']=command(guard,['uv','pip','freeze','--python',str(temp/'venv/bin/python')],30)['output']
    data['source_sha256']=sources()
    manifest={'source_sha256':data['source_sha256'],'build':data['build'],'dependency_artifacts':data['dependency_artifacts']}
    manifest['artifacts']={key:{'path':str(temp/path),'sha256':data['build'][key]['artifact_sha256']}
        for key,path in (('server-native','server'),('server-js','server.js'),('direct-native','direct'),('direct-js','direct.js'),('libevent','libevent'),('axum','rust/release/camber-public-axum'))}
    manifest['artifacts']['javascript-source']={'path':str(temp/'public_server.mjs'),'sha256':hashlib.sha256((temp/'public_server.mjs').read_bytes()).hexdigest()}
    (temp/'public-build.json').write_text(json.dumps(manifest,indent=2)+'\n')


def variants(temp):
    result={}
    for lane,argv in [('native-single',[str(temp/'server'),'--threads','1','--gpu','off']),('native-default',[str(temp/'server'),'--gpu','off']),('js',['bun',str(temp/'server.js')])]:
        for mode in ('raw','camber'): result[f'{mode}-{lane}']=(argv,mode,lane)
    result.update({'libevent':([str(temp/'libevent')],None,None),'axum':([str(temp/'rust/release/camber-public-axum')],None,None),
                   'flask':([str(temp/'venv/bin/python'),'-B',str(HERE/'public_flask.py')],None,None),
                   **{name:([('bun' if name=='elysia' else 'node'),str(temp/'public_server.mjs'),name],None,None) for name in ('node-http','fastify','hono','elysia')}})
    return result


def spawn(guard,temp,name,profile,headroom=False):
    argv,mode,lane=variants(temp)[name];port=freeport();control=freeport() if mode else None;env=ENV
    if mode: argv=argv+['camber-headroom' if headroom else mode,str(profile),str(port),str(control),str(128000000 if lane=='js' else 512000000)]
    elif name=='flask': env=dict(ENV,CAMBER_PROFILE=str(profile),CAMBER_PORT=str(port))
    else: argv=argv+[str(profile),str(port)]
    return Server(guard,argv,port,control,env,name)


async def direct(guard,temp,lane,row,mode,count):
    argv=['bun',str(temp/'direct.js')] if lane=='js' else [str(temp/'direct'),'--gpu','off']+(['--threads','1'] if lane=='native-single' else [])
    receipt=command(guard,argv+[mode,str(row[1]),row[0],row[2],row[3],str(count)],180)
    line=next(line for line in receipt['output'].splitlines() if line.startswith('DIRECT\t'))
    _,seconds,nanos,checksum=line.split('\t');expected=(row[5]+len(row[6]))*count % 2**32
    if int(checksum)!=expected: raise AssertionError((line,expected))
    receipt.update({'microseconds_per_request':(int(seconds)+int(nanos)/1e9)*1e6/count,'checksum':int(checksum),'iterations':count})
    return receipt


def freeze_live_budget(data,lane,row,repeats):
    workload=row[0];key=f'live:{lane}:{workload}'
    if key in data['numeric_budgets']: return
    rate=BUDGET['lanes']['js' if lane=='js' else 'native'][workload]['fixed_offered_requests_per_second']
    cells=[]
    for concurrency,offered in ((2,None),(16,None),(2,rate)):
        raw=[r for r in data['rows'] if r['implementation']==f'raw-{lane}' and r['workload']==workload and r['concurrency']==concurrency and r['offered_rate']==offered]
        if len(raw)!=repeats or any(r[p+'_ms'] is None for r in raw for p in ('p95','p99')):
            raise RuntimeError(f'cannot freeze paired numeric budget without complete raw observations: {key}')
        rps=statistics.median(r['responses_per_second'] for r in raw)
        latency={p:statistics.median(r[p+'_ms'] for r in raw) for p in ('p95','p99')}
        cells.append({'concurrency':concurrency,'offered_rate':offered,'raw_rps':rps,'minimum_rps':.9*rps,
                      'raw_latency_ms':latency,'latency_ceilings_ms':{p:value+max(.25,.2*value) for p,value in latency.items()},
                      'raw_trials':[r['trial'] for r in raw],'raw_all_pass':all(r['verdict']=='PASS' for r in raw)})
    data['numeric_budgets'][key]={'frozen_host_monotonic':time.monotonic(),'source_sha256':data['source_sha256'],'cells':cells}


async def direct_parity(guard,temp,lane,row,mode):
    argv=['bun',str(temp/'direct.js')] if lane=='js' else [str(temp/'direct'),'--gpu','off']+(['--threads','1'] if lane=='native-single' else [])
    body_path=temp/'direct-parity.bin'
    receipt=command(guard,argv+[f'parity-{mode}',str(row[1]),row[0],row[2],row[3],str(body_path)],180)
    lines=receipt['output'].splitlines();line=next(line for line in lines if line.startswith('PARITY\t'))
    _,status,length=line.split('\t')
    headers=dict(line[len('HEADER '):].split('=',1) for line in lines if line.startswith('HEADER '))
    headers['content-length']=length
    body=body_path.read_bytes()
    checksum=parity((int(status),headers,body),row)
    return {'lane':lane,'workload':row[0],'implementation':mode,'status':int(status),'headers':headers,
            'complete_body_bytes':len(body),'body_sha256':checksum,'dispatch_path':'same dispatch as timed loop','verdict':'PASS','command':receipt}


async def measure(guard,temp,data,output,smoke,implementation=None):
    rows=fixtures();names=[implementation] if implementation else list(variants(temp))
    if smoke: names=['raw-native-single','camber-native-single'];rows=rows[:1]
    data['measure_scope']={'live_implementations':names,'workloads':[row[0] for row in rows],
                           'direct_lanes':[] if smoke else ['native-single','native-default','js'],
                           'direct_implementations':[] if smoke else ['raw','camber']}
    save(output,data)
    repeats=1 if smoke else CRITERIA['trials'];duration=.1 if smoke else CRITERIA['trial_seconds']
    for name in names:
        for profile in sorted({r[1] for r in rows}):
            server=spawn(guard,temp,name,profile)
            try:
                startup=await server.ready();data['startup'].append({'implementation':name,'profile':profile,'seconds':startup,'pid':server.process.pid})
                for row in [r for r in rows if r[1]==profile]:
                    data['active_scenario']={'implementation':name,'workload':row[0],'phase':'live'}
                    if name.startswith('camber-'):
                        freeze_live_budget(data,name[len('camber-'):],row,repeats);save(output,data)
                    peer=await Peer.open(server.port)
                    try:
                        response=await peer.request(row[2],row[3],row[4])
                        data['parity'].append({'implementation':name,'workload':row[0],'status':response[0],'headers':response[1],'body_sha256':hashlib.sha256(response[2]).hexdigest()})
                        checksum=parity(response,row)
                    finally: await peer.close()
                    warmup=await load(server,row,.1 if smoke else CRITERIA['warmup_seconds'],2)
                    data['warmup'].append({'implementation':name,'workload':row[0],**warmup});save(output,data)
                    for trial in range(repeats):
                        lane='js' if name.endswith('-js') else 'native'
                        rate=BUDGET['lanes'][lane][row[0]]['fixed_offered_requests_per_second']
                        for concurrency,offered in [(2,None),(16,None),(2,rate)]:
                            sample=await load(server,row,duration,concurrency,offered)
                            data['rows'].append({'implementation':name,'workload':row[0],'trial':trial,'profile':profile,**sample})
                            save(output,data)
            finally:
                release=await server.close();data['release'].append(release);save(output,data)
                if release['forced'] or release['exit']!=0: raise RuntimeError('server release failed: '+str(release))
    if not smoke:
        for lane in ('native-single','native-default','js'):
            for row in fixtures():
                count=100 if row[0]=='echo-4m' else 10000
                for mode in ('raw','camber'):
                    data['active_scenario']={'implementation':mode,'lane':lane,'workload':row[0],'phase':'direct'}
                    if mode=='camber':
                        raw=[r['microseconds_per_request'] for r in data['direct'] if r['lane']==lane and r['workload']==row[0] and r['implementation']=='raw']
                        if len(raw)!=3: raise RuntimeError('missing direct raw observations')
                        baseline=statistics.median(raw)
                        data['numeric_budgets'][f'direct:{lane}:{row[0]}']={'frozen_host_monotonic':time.monotonic(),'raw_median_us':baseline,
                            'added_us_ceiling':min(10,max(2,.2*baseline)),'median_us_ceiling':baseline+min(10,max(2,.2*baseline))}
                        save(output,data)
                    data['direct_parity'].append(await direct_parity(guard,temp,lane,row,mode));save(output,data)
                    for trial in range(3):
                        data['direct'].append({'lane':lane,'workload':row[0],'implementation':mode,'trial':trial,**await direct(guard,temp,lane,row,mode,count)})
                        save(output,data)


async def overload(guard,temp,data,output):
    # Same PID across all cycles, no restart substituting for recovery.
    for name in [n for n in variants(temp) if n.startswith(('raw-','camber-'))]:
        server=spawn(guard,temp,name,0)
        try:
            await server.ready();initial=server.metrics()['rss_kib']
            for row in [r for r in fixtures() if r[0] in ('text','json-1k','echo-4m')]:
                for cycle in range(3):
                    baseline_index=len(guard.samples)
                    data['active_scenario']={'phase':'overload','implementation':name,'workload':row[0],'cycle':cycle}
                    offering_finished=asyncio.get_running_loop().create_future()
                    async def reduction_checkpoint():
                        offering=await offering_finished
                        boundary=offering['offering_finished_monotonic']+10
                        await asyncio.sleep(max(0,boundary-time.monotonic()))
                        actual_checkpoint=time.monotonic()
                        with guard.lock:
                            candidates=[s for s in guard.samples[baseline_index:]
                                        if offering['offering_finished_monotonic']<=s['host_monotonic']<=boundary
                                        and str(server.process.pid) in s['processes']]
                            on_time=max(candidates,key=lambda s:s['host_monotonic']) if candidates else None
                            table=guard.sample();current_observation=guard.samples[-1]['host_monotonic']
                        checkpoint={'requested_monotonic':boundary,'actual_checkpoint_monotonic':actual_checkpoint,
                                    'checkpoint_lateness_seconds':max(0,actual_checkpoint-boundary),
                                    'on_time_observation_monotonic':on_time['host_monotonic'] if on_time else None,
                                    'on_time_observation_age_seconds':boundary-on_time['host_monotonic'] if on_time else None,
                                    'on_time_rss_kib':on_time['processes'][str(server.process.pid)]['rss_kib'] if on_time else None,
                                    'current_observation_monotonic':current_observation,
                                    'current_observation_lateness_seconds':max(0,current_observation-boundary),
                                    'current_rss_kib':table.get(server.process.pid,{}).get('rss_kib')}
                        recovery=await load(server,fixtures()[0],1,1,rate=100)
                        checkpoint['recovery_started_monotonic']=recovery['measurement_started_monotonic']
                        checkpoint['recovery_finished_monotonic']=recovery['measurement_finished_monotonic']
                        checkpoint['recovery_start_lateness_seconds']=max(0,recovery['measurement_started_monotonic']-boundary)
                        return checkpoint,recovery
                    async def pressure_load():
                        try: return await load(server,row,30,64,allow_overload=True,offering_finished=offering_finished)
                        except BaseException as error:
                            if not offering_finished.done(): offering_finished.set_exception(error)
                            raise
                    pressure=asyncio.create_task(pressure_load())
                    reduction=asyncio.create_task(reduction_checkpoint())
                    joined=asyncio.gather(pressure,reduction,return_exceptions=True)
                    try: outcomes=await asyncio.shield(joined)
                    finally:
                        if not joined.done(): await asyncio.shield(joined)
                    for outcome in outcomes:
                        if isinstance(outcome,BaseException): raise outcome
                    sample,(checkpoint,recovery)=outcomes
                    offered_start=sample['measurement_started_monotonic']
                    window=[s['processes'][str(server.process.pid)]['rss_kib'] for s in guard.samples[baseline_index:]
                            if offered_start+20<=s['host_monotonic']<=offered_start+30 and str(server.process.pid) in s['processes']]
                    retained=checkpoint['on_time_rss_kib']
                    verdict='PASS' if window and max(window)<=4096*1024 and max(window)-min(window)<=64*1024 and retained is not None and retained<=initial+128*1024 and recovery['p99_ms'] is not None and recovery['p99_ms']<=100 and not recovery['errors'] and not recovery['generator_queue_drops'] and recovery['successful_responses']>=100 else 'FAIL/INCONCLUSIVE'
                    if sample['errors'] or sample['generator_queue_drops']: verdict='FAIL/INCONCLUSIVE'
                    data['overload'].append({'implementation':name,'pid':server.process.pid,'workload':row[0],'cycle':cycle,'initial_rss_kib':initial,'steady_window_rss_kib':window,'retained_rss_kib':retained,'retention_checkpoint':checkpoint,'sample':sample,'recovery':recovery,'verdict':verdict});save(output,data)
        finally: data['release'].append(await server.close());save(output,data)


def work_fixtures():
    cap=1048576
    dense=b'['+b'0,'*((cap-3)//2)+b'0]'
    depth=b'['*64+b'0,'*((cap-129)//2)+b'0'+b']'*64
    wide=json.dumps({str(n):0 for n in range(105425)},separators=(',',':')).encode()
    assert len(wide)<=cap
    return [('yield','yield',b''),('cpu','cpu',b''),
            ('dense-1m','parse',dense.ljust(cap,b' ')),
            ('depth64-1m','parse',depth.ljust(cap,b' ')),
            ('name-1m','validate',b'{"name":"'+b'a'*(cap-11)+b'"}'),
            ('unique-keys-1m','validate',wide.ljust(cap,b' '))]

async def overlap(guard,temp,data,output,completed_path=None):
    lanes=('camber-native-single','camber-native-default','camber-js');corpora=work_fixtures()
    eligible=[(name,workload,count,headroom,trial) for name in lanes for workload,_,_ in corpora
              for count,headroom in ((1,False),(16,False),(16,True)) for trial in range(3)]
    completed=set();prior_binding=None
    if completed_path is not None:
        prior_bytes=completed_path.read_bytes();history=json.loads(prior_bytes)
        if len(history.get('attempts',[]))!=1: raise ValueError('requires explicit original overlap attempt')
        prior=history['attempts'][0];prior_sources=prior['source_sha256']
        if prior['phase']!='overlap' or prior['criteria']!=CRITERIA or prior_sources!=prior['prepared_build']['source_sha256']:
            raise ValueError('prior overlap phase/criteria/source binding mismatch')
        if set(prior_sources)!=set(data['source_sha256']) or any(not isinstance(value,str) or len(value)!=64 or any(c not in '0123456789abcdef' for c in value) for value in prior_sources.values()):
            raise ValueError('invalid prior overlap source snapshot')
        if any(prior_sources[path]!=data['source_sha256'][path] for path in prior_sources if path!='camber/bench/run_public.py'):
            raise ValueError('prior overlap consumer/artifact inputs changed')
        if prior['prepared_build']['artifacts']!=data['prepared_build']['artifacts']:
            raise ValueError('prior overlap artifacts changed')
        keys=[(row['implementation'],row['corpus'],row['count'],row['headroom'],row['trial']) for row in prior['overlap']]
        if len(set(keys))!=len(keys) or any(key not in eligible for key in keys):
            raise ValueError('duplicate or invalid completed overlap identity')
        completed=set(keys)
        prior_binding={'path':str(completed_path),'sha256':hashlib.sha256(prior_bytes).hexdigest(),
                       'attempt_id':prior['attempt_id'],'source_sha256':prior_sources,
                       'completed_identities':keys,'active_scenario_not_completed':prior.get('active_scenario')}
    data['overlap_scope']={'prior_binding':prior_binding,'effective_source_sha256':data['source_sha256'],
                           'completed_identities_skipped':[key for key in eligible if key in completed],
                           'remaining_identities':[key for key in eligible if key not in completed]}
    save(output,data)
    for name in lanes:
        for workload,mode,body in corpora:
            for count,headroom in ((1,False),(16,False),(16,True)):
                for trial in range(3):
                    if (name,workload,count,headroom,trial) in completed: continue
                    data['active_scenario']={'phase':'overlap','implementation':name,'corpus':workload,'count':count,'headroom':headroom,'trial':trial}
                    server=spawn(guard,temp,name,0,headroom);peers=[];timeout_peer=None;ordinary=None
                    tasks=[];timeout_task=None;release_task=None
                    try:
                        await server.ready()
                        peers=[await Peer.open(server.port) for _ in range(count)]
                        starts=[time.monotonic() for _ in peers]
                        tasks=[asyncio.create_task(p.request('POST','/work/'+mode,body,work_id=str(index))) for index,p in enumerate(peers)]
                        deadline=time.monotonic()+30
                        while sum(r['text'].startswith('ARM '+mode) for r in server.lines)<count:
                            guard.check()
                            if time.monotonic()>deadline: raise RuntimeError('work admission/arm deadline')
                            await asyncio.sleep(.01)
                        # Arm an actual production header deadline before releasing work.
                        timeout_peer=await Peer.open(server.port)
                        timeout_peer.writer.write(b'GET /text HTTP/1.1\r\nHost: localhost\r\n');await timeout_peer.writer.drain();armed=time.monotonic()
                        async def timeout_result():
                            chunks=[];chunk_receipts=[];read_error=None;peer_eof=False
                            try:
                                async with asyncio.timeout(120):
                                    while True:
                                        chunk=await timeout_peer.reader.read(65536)
                                        received=time.monotonic()
                                        if not chunk: peer_eof=True;break
                                        chunks.append(chunk);chunk_receipts.append({'client_received_monotonic':received,'bytes':len(chunk)})
                            except Exception as error: read_error=repr(error)
                            delivered=time.monotonic();raw=b''.join(chunks);status=None;headers={};complete_response=False;framing_error=None
                            try:
                                head,separator,payload=raw.partition(b'\r\n\r\n')
                                if not separator: raise ValueError('incomplete timeout response headers')
                                lines=head.decode('latin1').split('\r\n');status=int(lines[0].split()[1])
                                if not lines[0].startswith('HTTP/1.1 '): raise ValueError('invalid timeout response status line')
                                headers=dict((key.lower(),value.strip()) for key,value in (line.split(':',1) for line in lines[1:]))
                                complete_response=read_error is None and peer_eof and int(headers['content-length'])==len(payload)
                                if not complete_response: framing_error='incomplete/error timeout response'
                            except (ValueError,KeyError,IndexError) as error: framing_error=repr(error)
                            return {'client_armed_monotonic':armed,'client_delivery_monotonic':delivered,
                                    'bytes_hex':raw.hex(),'received_408':complete_response and status==408,
                                    'status':status,'headers':headers,'peer_eof':peer_eof,'response_error':read_error,
                                    'framing_error':framing_error,'complete_response_received':complete_response,
                                    'received_chunks':chunk_receipts}
                        timeout_task=asyncio.create_task(timeout_result())
                        async def release_work():
                            control=await Peer.open(server.control)
                            try:
                                for _ in range(count): await control.request('POST','/release',b'')
                            finally: await control.close()
                        release_task=asyncio.create_task(release_work())
                        await asyncio.sleep(.001)
                        ordinary_started=time.monotonic();ordinary_error=None;ordinary_partial_hex=None
                        ordinary_response=(None,{},b'');ordinary_exact=False;ordinary_parity_error=None
                        try:
                            ordinary=await Peer.open(server.port)
                            ordinary_response=await ordinary.request('GET','/probe',b'')
                        except Exception as error:
                            ordinary_error=repr(error)
                            if isinstance(error,asyncio.IncompleteReadError): ordinary_partial_hex=error.partial.hex()
                        finally:
                            ordinary_finished=time.monotonic()
                            if ordinary: await ordinary.close();ordinary=None
                        if ordinary_error is None:
                            try: parity(ordinary_response,fixtures()[0]);ordinary_exact=True
                            except AssertionError as error: ordinary_parity_error=str(error)
                        # At capacity, ordinary may be a real 503; preserve it, do not call it progress.
                        responses=await asyncio.gather(*tasks);work_finished=time.monotonic()
                        await release_task
                        timeout=await timeout_task
                        expected={'yield':(200,b'yielded'),'parse':(200,b'parsed'),'validate':(400,b'invalid name')}
                        work_exact=all((r[0],r[2])==expected[mode] for r in responses) if mode!='cpu' else all(r[0]==200 and r[2].isdigit() and int(r[2])<=4294967295 for r in responses)
                        for p in peers: await p.close()
                        peers=[]
                        recovery=await Peer.open(server.port);recovery_started=time.monotonic();parity(await recovery.request('GET','/text',b''),fixtures()[0]);recovery_ms=(time.monotonic()-recovery_started)*1000;await recovery.close()
                        events=[]
                        for line in server.lines:
                            fields=line['text'].split('\t')
                            if len(fields)==3 and fields[0].startswith(('BEGIN ','END ','TIMEOUT_DELIVERED','ORDINARY')):
                                events.append({'label':fields[0],'internal_monotonic':int(fields[1])+int(fields[2])/1e9,'host_receipt_monotonic':line['host_receipt_monotonic']})
                        beginnings={e['label'].split()[-1]:e['internal_monotonic'] for e in events if e['label'].startswith('BEGIN ')}
                        endings={e['label'].split()[-1]:e['internal_monotonic'] for e in events if e['label'].startswith('END ')}
                        intervals=[{'work_id':str(index),'begin':beginnings[str(index)],'end':endings[str(index)]} for index in range(count) if str(index) in beginnings and str(index) in endings]
                        client_overlaps=any(ordinary_started<end['host_receipt_monotonic'] and ordinary_finished>begin['host_receipt_monotonic']
                            for begin in events if begin['label'].startswith('BEGIN ')
                            for end in events if end['label']=='END '+begin['label'][len('BEGIN '):])
                        ordinary_times=[e['internal_monotonic'] for e in events if e['label']=='ORDINARY']
                        handler_progress=any(interval['begin']<=point<=interval['end'] for point in ordinary_times for interval in intervals)
                        timeout_ms=(timeout['client_delivery_monotonic']-armed)*1000
                        data['overlap'].append({'implementation':name,'workload':mode,'count':count,'trial':trial,'pid':server.process.pid,'input_bytes':len(body),'work_client_started':starts,'work_client_finished':work_finished,'work_statuses':[r[0] for r in responses],'work_body_sha256':[hashlib.sha256(r[2]).hexdigest() for r in responses],'internal_events':events,'ordinary_started':ordinary_started,'ordinary_finished':ordinary_finished,'ordinary_status':ordinary_response[0],'ordinary_body_sha256':hashlib.sha256(ordinary_response[2]).hexdigest(),'ordinary_latency_ms':(ordinary_finished-ordinary_started)*1000,'client_overlaps_host_log_receipts':client_overlaps,'timeout':timeout,'timeout_delivery_ms':timeout_ms,'recovery_latency_ms':recovery_ms,'verdict':'PASS' if ordinary_exact and handler_progress and (ordinary_finished-ordinary_started)*1000<=100 and timeout['received_408'] and timeout_ms<=300 and recovery_ms<=100 else 'FAIL/INCONCLUSIVE'})
                        data['overlap'][-1].update({'headroom':headroom,'active_request_limit':18 if headroom else 16,
                            'work_intervals':intervals,'ordinary_handler_times':ordinary_times,'ordinary_handler_during_work':handler_progress,
                            'ordinary_headers':ordinary_response[1],'ordinary_complete_body_hex':ordinary_response[2].hex(),
                            'client_overlap_clock_basis':'host log receipt only; buffered receipt is not handler-progress proof',
                            'ordinary_response_exact':ordinary_exact,'ordinary_parity_error':ordinary_parity_error,
                            'ordinary_response_error':ordinary_error,'ordinary_received_partial_hex':ordinary_partial_hex,
                            'ordinary_complete_response_received':ordinary_error is None,
                            'ordinary_body_sha256':None if ordinary_error else hashlib.sha256(ordinary_response[2]).hexdigest(),
                            'ordinary_complete_body_hex':None if ordinary_error else ordinary_response[2].hex(),
                            'timeout_admitted_and_expired':timeout['received_408'],'timeout_capacity_rejection':timeout['complete_response_received'] and timeout['status']==503})
                        if not ordinary_exact or not handler_progress or len(intervals)!=count:
                            data['overlap'][-1]['verdict']='FAIL/INCONCLUSIVE'
                        data['overlap'][-1]['corpus']=workload
                        data['overlap'][-1]['work_responses_exact']=work_exact
                        if not work_exact: data['overlap'][-1]['verdict']='FAIL/INCONCLUSIVE'
                        save(output,data)
                    finally:
                        pending=[task for task in [*tasks,timeout_task,release_task] if task is not None]
                        for task in pending:
                            if not task.done(): task.cancel()
                        if pending: await asyncio.gather(*pending,return_exceptions=True)
                        if ordinary: await ordinary.close()
                        for p in peers: await p.close()
                        if timeout_peer: await timeout_peer.close()
                        data['release'].append(await server.close());save(output,data)


def gates(data):
    report=[]
    for lane in ('native-single','native-default','js'):
        historical=BUDGET['lanes']['js' if lane=='js' else 'native']
        for row in fixtures():
            label=row[0];direct_rows=[r for r in data['direct'] if r['lane']==lane and r['workload']==label]
            if direct_rows:
                med={mode:statistics.median(r['microseconds_per_request'] for r in direct_rows if r['implementation']==mode) for mode in ('raw','camber')}
                budget=data['numeric_budgets'][f'direct:{lane}:{label}']
                ceiling=budget['median_us_ceiling']
                report.append({'lane':lane,'workload':label,'gate':'direct','raw_us':med['raw'],'camber_us':med['camber'],'paired_ceiling_us':ceiling,'historical_ceiling_us':historical[label]['direct_ceiling_us'],'paired_pass':med['camber']<=ceiling,'historical_pass':med['camber']<=historical[label]['direct_ceiling_us']})
            for concurrency,rate in [(2,False),(16,False),(2,True)]:
                selected={mode:[r for r in data['rows'] if r['implementation']==mode+'-'+lane and r['workload']==label and r['concurrency']==concurrency and (r['offered_rate'] is not None)==rate] for mode in ('raw','camber')}
                if not all(selected.values()): continue
                raw_rps=statistics.median(r['responses_per_second'] for r in selected['raw']);camber_rps=statistics.median(r['responses_per_second'] for r in selected['camber'])
                latency={mode:{} for mode in selected}
                for mode,observations in selected.items():
                    for p in ('p95','p99'):
                        values=[r[p+'_ms'] for r in observations if r[p+'_ms'] is not None]
                        latency[mode][p]=statistics.median(values) if values else None
                budget=next(cell for cell in data['numeric_budgets'][f'live:{lane}:{label}']['cells']
                            if cell['concurrency']==concurrency and (cell['offered_rate'] is not None)==rate)
                ceilings=budget['latency_ceilings_ms']
                prefix='fixed_rate' if rate else 'saturation'
                paired=camber_rps>=budget['minimum_rps'] and all(latency['camber'][p] is not None and latency['camber'][p]<=ceilings[p] for p in ceilings) and all(r['verdict']=='PASS' for observations in selected.values() for r in observations)
                absolute=(rate or camber_rps>=historical[label]['minimum_closed_loop_responses_per_second']) and all(latency['camber'][p] is not None and latency['camber'][p]<=historical[label][prefix+'_'+p+'_ms_ceiling'] for p in ceilings)
                report.append({'lane':lane,'workload':label,'gate':prefix,'concurrency':concurrency,'raw_rps':raw_rps,'camber_rps':camber_rps,'paired_latency_ceilings_ms':ceilings,'latencies_ms':latency,'paired_pass':paired,'historical_pass':absolute})
    return report


async def execute(args,guard,temp,data):
    if args.phase=='bend-smoke':
        target=temp/'server'
        receipt=command(guard,['bend',str(HERE/'public_main.bend'),'-o',str(target)],300)
        receipt['artifact_bytes']=target.stat().st_size
        receipt['artifact_sha256']=hashlib.sha256(target.read_bytes()).hexdigest()
        data['build']['server-native']=receipt;save(args.output,data)
        await measure(guard,temp,data,args.output,True)
        return
    if args.phase in ('build','smoke','full'): prepare(guard,temp,data);save(args.output,data)
    if args.phase=='build': return
    manifest=json.loads((temp/'public-build.json').read_text())
    if manifest['source_sha256']!=sources(): raise RuntimeError('prepared artifact source snapshot mismatch; rebuild under a new grant')
    for artifact in manifest['artifacts'].values():
        if hashlib.sha256(Path(artifact['path']).read_bytes()).hexdigest()!=artifact['sha256']:
            raise RuntimeError('prepared artifact hash mismatch: '+artifact['path'])
    data['prepared_build']=manifest;save(args.output,data)
    if args.phase in ('smoke','full','measure'): await measure(guard,temp,data,args.output,args.phase=='smoke',args.measure_implementation)
    if args.phase in ('full','overload'): await overload(guard,temp,data,args.output)
    if args.phase in ('full','overlap'): await overlap(guard,temp,data,args.output,args.overlap_completed)
    data['gates']=gates(data)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phase',choices=('bend-smoke','build','smoke','measure','overload','overlap','full'),required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--scratch',type=Path,required=True,help='Owned prepared artifacts, explicitly removed after release')
    parser.add_argument('--measure-implementation',choices=tuple(variants(Path('.'))),help='Only this live implementation; non-smoke direct measurement remains complete')
    parser.add_argument('--overlap-completed',type=Path,help='Original source-bound completed overlap identities to skip; default runs all162 trials')
    args=parser.parse_args()
    if args.measure_implementation and args.phase!='measure': parser.error('--measure-implementation requires --phase measure')
    if args.overlap_completed and args.phase!='overlap': parser.error('--overlap-completed requires --phase overlap')
    if os.environ.get('CAMBER_RUNTIME_SLOT')!='340': parser.error('requires explicit coordinator slot; set CAMBER_RUNTIME_SLOT=340 only after grant')
    args.scratch.mkdir(parents=True,exist_ok=True)
    data={'attempt_id':str(time.time_ns()),'phase':args.phase,'source_sha256':sources(),'criteria':CRITERIA,'platform':platform.platform(),'versions':{},'build':{},'startup':[],'parity':[],'direct_parity':[],'warmup':[],'rows':[],'direct':[],'overload':[],'overlap':[],'release':[],'commands':[],'server_commands':[],'numeric_budgets':{},'verdict':'INCONCLUSIVE'}
    save(args.output,data)
    guard=Guard(data,args.output)
    try:
        data['versions']={'bend':command(guard,['bend','version'],30)['output'].strip()} if args.phase=='bend-smoke' else versions(guard)
        save(args.output,data)
        asyncio.run(execute(args,guard,args.scratch,data))
        data['verdict']='PASS' if args.phase=='full' and all(r['verdict']=='PASS' for section in ('warmup','rows','overload','overlap') for r in data[section]) and all(r.get('paired_pass') and r.get('historical_pass') for r in data.get('gates',[])) else 'FAIL/INCONCLUSIVE'
    except BaseException as error:
        data['failure']=str(error);data['verdict']='FAIL/INCONCLUSIVE'
        guard.kill()
        raise
    finally:
        try: guard.close()
        except BaseException as error: guard.cleanup_errors.append('guard close: '+repr(error))
        finally:
            data['guard_samples']=guard.samples;data['aggregate_peak_rss_kib']=guard.peak_kib
            data['guard_failure']=guard.failure;data['cleanup_errors']=guard.cleanup_errors
            if guard.failure or guard.cleanup_errors or any(r.get('forced') or not r.get('released',r.get('observed_descendants_released',False)) for r in data['release']):
                data['verdict']='FAIL/INCONCLUSIVE'
            try: save(args.output,data)
            except BaseException as error:
                data['verdict']='FAIL/INCONCLUSIVE';guard.cleanup_errors.append('final evidence save: '+repr(error))
                print('FINAL EVIDENCE SAVE FAILED: '+repr(error),flush=True)
                raise


if __name__=='__main__': main()
