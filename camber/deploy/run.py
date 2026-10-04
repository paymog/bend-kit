#!/usr/bin/env python3
"""Observe launchd-owned jobs; Python never owns or kills a passing Bend child."""
import argparse
import hashlib
import json
import os
import platform
import plistlib
import re
import select
import shutil
import signal
import socket
import ssl
import subprocess
import tempfile
import threading
import time
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
APP, ADMIN, BLOCKING_IO, TLS = 19441, 19442, 19443, 19444
GRACE, TEARDOWN = 5.0, 1.0
DOMAIN = f"gui/{os.getuid()}"
ENV = {**os.environ, "BEND_NO_TELEMETRY": "1"}


def disk_floor():
    if shutil.disk_usage(ROOT).free < 10 * 1024**3:
        raise RuntimeError("less than 10 GiB free disk")


# Same PID/lstart identity and descendant receipt pattern as ../run_serving.py.
def processes():
    disk_floor()
    rows = {}
    output = subprocess.check_output(["ps", "-axo", "pid=,ppid=,rss=,lstart="], text=True)
    for line in output.splitlines():
        pid, parent, rss, identity = line.split(None, 3)
        rows[int(pid)] = (int(parent), int(rss), identity)
    return rows


class Evidence:
    def __init__(self, path, invocation):
        self.path = path
        self.lock = threading.Lock()
        prior = json.loads(path.read_text()) if path.exists() else {"invocations": []}
        # Never discard an earlier schema or unfavorable invocation.
        self.history = prior if isinstance(prior, dict) and "invocations" in prior else {"invocations": [prior]}
        self.history["invocations"].append(invocation)
        self.invocation = invocation
        self.save()

    def save(self):
        with self.lock:
            temporary = self.path.with_name(self.path.name + f".{os.getpid()}.tmp")
            with temporary.open("w") as output:
                json.dump(self.history, output, indent=2)
                output.write("\n")
                output.flush()
                os.fsync(output.fileno())
            os.replace(temporary, self.path)


def lifecycle_projection(argv, text, jobs):
    if len(argv) < 2 or Path(argv[0]).name != "launchctl":
        return text
    if argv[1] == "print":
        # Closed projection: no environment, argv, inherited service sections or diagnostics.
        numeric = r"(?:pid|runs|last exit code|exit timeout) = -?[0-9]+"
        state = r"state = (?:running|not running|waiting|exited)"
        terminating = r"last terminating signal = (?:Killed|Terminated|9|15|SIGKILL|SIGTERM)"
        return "\n".join(line.strip() for line in text.splitlines()
                         if re.fullmatch(rf"(?:{numeric}|{state}|{terminating})", line.strip())) + "\n"
    if argv[1] == "list":
        labels = {job["target"].rsplit("/", 1)[1] for job in jobs}
        return "\n".join(line for line in text.splitlines()
                         if len(line.split()) == 3 and line.split()[-1] in labels) + "\n"
    return text


class Guard:
    def __init__(self, evidence):
        self.evidence = evidence
        self.lock = threading.RLock()
        self.roots = {}
        self.observed = {}
        self.trees = {}
        self.peak_kib = 0
        self.failure = None
        self.forced_cleanup = False
        self.closed = threading.Event()
        self.register(os.getpid())
        self.thread = threading.Thread(target=self.monitor)
        self.thread.start()

    def register(self, pid):
        rows = processes()
        with self.lock:
            if pid in rows:
                self.roots[pid] = rows[pid][2]
                self.trees.setdefault(pid, {})[pid] = rows[pid][2]
            self.sample(rows)

    def unregister(self, pid):
        with self.lock:
            self.roots.pop(pid, None)

    def sample(self, rows):
        with self.lock:
            owned = set()
            for root, identity in self.roots.items():
                tree = self.trees[root]
                members = {pid for pid, known in tree.items() if pid in rows and rows[pid][2] == known}
                if root in rows and rows[root][2] == identity:
                    members.add(root)
                while True:
                    expanded = members | {pid for pid, (parent, rss, identity) in rows.items() if parent in members}
                    if expanded == members:
                        break
                    members = expanded
                for pid in members:
                    tree[pid] = rows[pid][2]
                    self.observed[pid] = rows[pid][2]
                owned |= members
            self.peak_kib = max(self.peak_kib, sum(rows[pid][1] for pid in owned))
            return owned

    def surviving(self, identities):
        rows = processes()
        return {pid: identity for pid, identity in identities.items() if pid in rows and rows[pid][2] == identity}

    def kill_exact(self, identities):
        self.forced_cleanup = True
        survivors = self.surviving(identities)
        for pid in survivors:
            if pid != os.getpid():
                try:
                    os.kill(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
        return survivors

    def monitor(self):
        try:
            while not self.closed.wait(.05):
                rows = processes()
                self.sample(rows)
                if self.peak_kib > 20 * 1024**2:
                    raise RuntimeError("aggregate owned roots/descendants exceeded 20 GiB RSS")
        except BaseException as error:
            self.failure = repr(error)
            record = {"failure": self.failure, "observed_process_identities": dict(self.observed)}
            try:
                record["safety_kill_identities"] = self.kill_exact(dict(self.observed))
            except BaseException as cleanup_error:
                record["safety_cleanup_failure"] = repr(cleanup_error)
            self.evidence.invocation["guard_failures"].append(record)
            self.evidence.save()

    def check(self):
        if self.failure:
            raise RuntimeError(self.failure)
        disk_floor()

    def command(self, argv, timeout=20, check=True, cleanup=False):
        record = {"argv": list(map(str, argv)), "cwd": str(ROOT), "started_monotonic": time.monotonic(),
                  "status": None, "root_pid": None, "root_reaped": False, "forced_cleanup": False,
                  "observed_process_identities": {}, "surviving_observed_processes": {}}
        with self.evidence.lock:
            index = len(self.evidence.invocation["commands"])
            self.evidence.invocation["commands"].append(dict(record))
        self.evidence.save()
        process = None
        failure = None
        with tempfile.TemporaryFile(mode="w+t") as out, tempfile.TemporaryFile(mode="w+t") as err:
            try:
                disk_floor() if cleanup else self.check()
                process = subprocess.Popen(record["argv"], cwd=ROOT, env=ENV, stdout=out, stderr=err,
                                           start_new_session=True)
                record["root_pid"] = process.pid
                try:
                    self.register(process.pid)
                except BaseException as identity_error:
                    record["identity_capture_failure"] = repr(identity_error)
                    if not cleanup:
                        raise
                    # Failure-release commands still execute; missing identity proof
                    # remains an adverse receipt, never a passing invocation.
                    failure = identity_error
                with self.evidence.lock:
                    self.evidence.invocation["commands"][index] = dict(record)
                self.evidence.save()
                deadline = time.monotonic() + timeout
                while process.poll() is None:
                    disk_floor() if cleanup else self.check()
                    if time.monotonic() > deadline:
                        raise TimeoutError(f"command exceeded {timeout}s")
                    time.sleep(.02)
                record["status"] = process.returncode
                if check and process.returncode:
                    raise RuntimeError(f"command exited {process.returncode}")
            except BaseException as error:
                failure = error
                record["failure"] = repr(error)
            finally:
                if process:
                    try:
                        self.sample(processes())
                        identities = dict(self.trees.get(process.pid, {}))
                        record["observed_process_identities"] = identities
                        survivors = self.surviving(identities)
                        if process.poll() is None or survivors:
                            record["forced_cleanup"] = True
                            # A verified live root owns this process group. Catch compiler
                            # descendants born between samples without touching other groups.
                            root_identity = identities.get(process.pid)
                            current = processes()
                            if process.pid in current and current[process.pid][2] == root_identity:
                                os.killpg(process.pid, signal.SIGKILL)
                                record["forced_group_cleanup"] = True
                            record["cleanup_kill_identities"] = self.kill_exact(identities)
                            failure = failure or RuntimeError("command required forced descendant cleanup")
                        process.wait(timeout=5)
                        record["root_reaped"] = True
                        record["status"] = process.returncode
                        deadline = time.monotonic() + 5
                        survivors = self.surviving(identities)
                        while survivors and time.monotonic() < deadline:
                            time.sleep(.05)
                            survivors = self.surviving(identities)
                        record["surviving_observed_processes"] = survivors
                        record["observed_descendants_released"] = not survivors
                        if survivors:
                            failure = failure or RuntimeError("command descendants survived cleanup")
                    except BaseException as cleanup_error:
                        record["cleanup_failure"] = repr(cleanup_error)
                        failure = failure or cleanup_error
                        record["descendant_release_unobserved"] = True
                        try:
                            if process.poll() is None:
                                # Popen's unreaped child cannot have its PID reused.
                                record["forced_cleanup"] = True
                                record["forced_group_cleanup"] = True
                                os.killpg(process.pid, signal.SIGKILL)
                            process.wait(timeout=5)
                            record.update(root_reaped=True, status=process.returncode)
                        except BaseException as reap_error:
                            record["root_reap_failure"] = repr(reap_error)
                    finally:
                        self.unregister(process.pid)
                out.seek(0)
                err.seek(0)
                stdout = lifecycle_projection(record["argv"], out.read(), self.evidence.invocation["platform_jobs"])
                stderr = err.read()
                if Path(record["argv"][0]).name == "launchctl" and record["argv"][1] in ("print", "list"):
                    stderr = "" if not stderr else "launchctl diagnostic omitted; see command status"
                record.update(stdout=stdout, stderr=stderr,
                              elapsed_seconds=time.monotonic() - record["started_monotonic"])
                if failure:
                    record["failure"] = repr(failure)
                with self.evidence.lock:
                    self.evidence.invocation["commands"][index] = record
                self.evidence.save() # Durable even for nonzero, timeout, guard or release failure.
        if failure:
            raise RuntimeError(record) from failure
        return record

    def close(self):
        self.closed.set()
        self.thread.join()
        record = {"guard_failure": self.failure, "sampled_aggregate_peak_rss_kib": self.peak_kib,
                  "forced_cleanup": self.forced_cleanup, "observed_process_identities": dict(self.observed)}
        try:
            identities = {pid: identity for pid, identity in self.observed.items() if pid != os.getpid()}
            survivors = self.surviving(identities)
            if survivors:
                record["forced_cleanup"] = True
                self.kill_exact(survivors)
                deadline = time.monotonic() + 5
                while survivors and time.monotonic() < deadline:
                    time.sleep(.05)
                    survivors = self.surviving(identities)
            record["surviving_observed_processes"] = survivors
        except BaseException as error:
            record["cleanup_failure"] = repr(error)
        self.evidence.invocation["guard_release"] = record
        self.evidence.save()
        return record


def refused(port):
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=.1):
            return False
    except ConnectionRefusedError:
        return True


def wait_until(guard, predicate, timeout=10, cleanup=False):
    deadline = time.monotonic() + timeout
    while True:
        disk_floor() if cleanup else guard.check()
        result = predicate()
        if result:
            return result
        if time.monotonic() > deadline:
            raise TimeoutError("observation deadline")
        time.sleep(.01)


class Job:
    def __init__(self, guard, directory, label, argv):
        self.guard, self.directory, self.label = guard, directory, label
        self.target = f"{DOMAIN}/{label}"
        self.output = directory / f"{label}.out"
        self.error = directory / f"{label}.err"
        self.plist = directory / f"{label}.plist"
        self.pid = None
        self.queue = None
        self.loaded = False
        self.stop_thread = None
        self.stop_error = None
        self.events = []
        self.commands = []
        config = {"Label": label, "ProgramArguments": list(map(str, argv)),
                  "WorkingDirectory": str(directory), "RunAtLoad": True,
                  "KeepAlive": False, "ExitTimeOut": 5, "Umask": 63,
                  "EnvironmentVariables": {"BEND_NO_TELEMETRY": "1"},
                  "StandardOutPath": str(self.output), "StandardErrorPath": str(self.error),
                  "HardResourceLimits": {"Core": 0}}
        self.record = {"target": self.target, "rendered_plist": config, "platform_commands": self.commands,
                       "observed_markers": self.events, "source_sha256": guard.evidence.invocation["source_sha256"]}
        guard.evidence.invocation["platform_jobs"].append(self.record)
        guard.evidence.save()
        try:
            self.plist.write_bytes(plistlib.dumps(config))
            self.loaded = True # Exact unique label may exist even if bootstrap receipt fails.
            self.commands.append(guard.command(["launchctl", "bootstrap", DOMAIN, self.plist]))
            self.initial = wait_until(guard, self.snapshot)
            self.pid = int(re.search(r"\bpid = (\d+)", self.initial).group(1))
            guard.register(self.pid) # Actual platform root, not a harness descendant.
            self.identity = guard.roots[self.pid]
            self.parent = guard.command(["ps", "-o", "ppid=", "-p", self.pid])["stdout"].strip()
            self.record.update(pid=self.pid, root_identity=self.identity, parent_pid=self.parent,
                               launchd_initial_state=self.initial)
            guard.evidence.save()
            assert self.parent == "1", (self.pid, self.parent)
            self.queue = select.kqueue()
            self.queue.control([select.kevent(self.pid, filter=select.KQ_FILTER_PROC,
                                            flags=select.KQ_EV_ADD | select.KQ_EV_ENABLE,
                                            fflags=select.KQ_NOTE_EXIT)], 0, 0)
        except BaseException as error:
            self.record["startup_failure"] = repr(error)
            self.release()
            raise

    def snapshot(self):
        record = self.guard.command(["launchctl", "print", self.target], check=False)
        self.commands.append(record)
        return record["stdout"] if re.search(r"\bpid = (\d+)", record["stdout"]) else None

    def text(self):
        return self.output.read_text() if self.output.exists() else ""

    def marker(self, marker):
        wait_until(self.guard, lambda: marker in self.text())
        record = {"marker": marker, "observed_monotonic": time.monotonic()}
        self.events.append(record)
        self.guard.evidence.save()
        return record["observed_monotonic"]

    def request_stop(self):
        self.guard.check()
        self.requested = time.monotonic()
        self.record["platform_stop_requested_monotonic"] = self.requested
        self.guard.evidence.save()
        # Retain the job's last exit status; launchd owns its ExitTimeOut deadline.
        def stop():
            try:
                self.commands.append(self.guard.command(["launchctl", "stop", self.label], timeout=10))
            except BaseException as error:
                self.stop_error = repr(error)
                self.record["stop_command_failure"] = self.stop_error
                self.guard.evidence.save()
        self.stop_thread = threading.Thread(target=stop)
        self.stop_thread.start()
        return self.requested

    def exited(self):
        alive_samples = []
        def observe_exit():
            events = self.queue.control(None, 1, 0)
            if not events:
                alive_samples.append(time.monotonic())
            return events
        events = wait_until(self.guard, observe_exit, timeout=7)
        event = events[0]
        exited = time.monotonic()
        # NOTE_EXIT proves kernel exit; exact PID/lstart absence separately proves reap.
        wait_until(self.guard, lambda: not self.guard.surviving({self.pid: self.identity}), timeout=1)
        reaped = time.monotonic()
        self.finish_stop()
        platform = self.guard.command(["launchctl", "list"])
        line = next(line for line in platform["stdout"].splitlines() if line.split()[-1:] == [self.label])
        status = int(line.split()[1])
        self.commands.append({**platform, "stdout": line})
        result = {"kernel_note_exit": event.fflags, "platform_last_exit_status": status,
                  "kernel_exit_not_yet_observed_monotonic_samples": alive_samples,
                  "exit_observed_monotonic": exited, "reap_observed_monotonic": reaped,
                  "stop_to_exit_seconds": exited - self.requested,
                  "stop_to_reap_seconds": reaped - self.requested}
        self.record["exit"] = result
        self.guard.evidence.save()
        if self.stop_error:
            raise RuntimeError(self.stop_error)
        return result

    def finish_stop(self):
        if self.stop_thread:
            self.stop_thread.join(timeout=16)
            if self.stop_thread.is_alive():
                raise RuntimeError("bounded platform-stop command did not finish")
            self.stop_thread = None

    def release(self):
        release = {"forced_cleanup": False, "errors": [], "job_unregistered": False}
        self.record["release"] = release
        try:
            self.finish_stop()
        except BaseException as error:
            release["errors"].append(repr(error))
        if self.pid:
            release["observed_process_identities"] = dict(self.guard.trees.get(self.pid, {}))
            try:
                release["forced_cleanup"] = bool(self.guard.surviving(release["observed_process_identities"]))
            except BaseException as error:
                release["errors"].append(repr(error))
        # Every release step is independent: an observation failure cannot skip bootout.
        if self.loaded:
            try:
                receipt = self.guard.command(["launchctl", "bootout", self.target], timeout=10,
                                             check=False, cleanup=True)
                self.commands.append(receipt)
                self.loaded = False
            except BaseException as error:
                release["errors"].append(repr(error))
        if self.pid:
            try:
                identities = release["observed_process_identities"]
                deadline = time.monotonic() + 7
                survivors = self.guard.surviving(identities)
                while survivors and time.monotonic() < deadline:
                    time.sleep(.05)
                    survivors = self.guard.surviving(identities)
                if survivors:
                    release["forced_cleanup"] = True
                    release["safety_kill_identities"] = self.guard.kill_exact(survivors)
                    deadline = time.monotonic() + 5
                    while survivors and time.monotonic() < deadline:
                        time.sleep(.05)
                        survivors = self.guard.surviving(identities)
                release["surviving_observed_processes"] = survivors
                release["observed_descendants_released"] = not survivors
                self.guard.unregister(self.pid)
            except BaseException as error:
                release["errors"].append(repr(error))
                release["descendant_release_unobserved"] = True
        try:
            receipt = self.guard.command(["launchctl", "print", self.target], check=False, cleanup=True)
            self.commands.append(receipt)
            release["job_unregistered"] = receipt["status"] != 0
        except BaseException as error:
            release["errors"].append(repr(error))
        finally:
            if self.queue:
                self.queue.close()
                self.queue = None
            self.record.update(stdout=self.text(), stderr=self.error.read_text() if self.error.exists() else "")
            release["released"] = (release["job_unregistered"] and not release["errors"]
                                   and not release.get("surviving_observed_processes"))
            self.guard.evidence.save()
        return release


def read_response(peer):
    data = b""
    while b"\r\n\r\n" not in data:
        part = peer.recv(65536)
        if not part:
            raise AssertionError(("response headers truncated", data))
        data += part
    head, body = data.split(b"\r\n\r\n", 1)
    headers = dict(line.split(b":", 1) for line in head.split(b"\r\n")[1:])
    headers = {key.lower(): value.strip() for key, value in headers.items()}
    length = int(headers[b"content-length"])
    while len(body) < length:
        part = peer.recv(65536)
        if not part:
            raise AssertionError(("response body truncated", body))
        body += part
    return int(head.split()[1]), headers, body


def request(port, target, *, context=None, method=b"GET", body=b"", headers=(), connection=b"close"):
    peer = socket.create_connection(("127.0.0.1", port), timeout=2)
    if context:
        peer = context.wrap_socket(peer, server_hostname="localhost")
    peer.settimeout(3)
    peer.sendall(method + b" " + target + b" HTTP/1.1\r\nHost: localhost\r\n"
                 + b"Authorization: Bearer seven\r\nConnection: " + connection + b"\r\n"
                 + b"Content-Length: " + str(len(body)).encode() + b"\r\n"
                 + b"".join(key + b": " + value + b"\r\n" for key, value in headers)
                 + b"\r\n" + body)
    return peer


def peer_closed(peer):
    peer.settimeout(.05)
    try:
        return peer.recv(1) == b""
    except ConnectionResetError:
        return True
    except socket.timeout:
        return False


def cooperative(guard, job):
    idle = request(APP, b"/health", connection=b"keep-alive")
    assert read_response(idle)[0] == 200
    peer = request(APP, b"/users/me")
    try:
        job.marker("WORK ADMITTED")
        job.request_stop()
        wait_until(guard, lambda: refused(APP), timeout=1)
        refused_at = time.monotonic()
        wait_until(guard, lambda: peer_closed(idle), timeout=1)
        idle_at = time.monotonic()
        status, headers, body = read_response(peer)
        completed = time.monotonic()
        assert status == 200 and body == b'{"id":7,"name":"Alice"}'
        assert all(headers[b"x-" + scope] == b"yes" for scope in (b"root", b"group", b"route"))
        result = job.exited()
        assert result["platform_last_exit_status"] == 0, result
        assert result["stop_to_reap_seconds"] <= GRACE, result
        for marker in ("WORK COMPLETED", "APPLICATION JOINED", "TRANSPORT OWNER COMPLETED",
                       "STORE CLOSED", "STORE JOINED", "ADMIN OWNER COMPLETED", "NATURAL EXIT READY"):
            job.marker(marker)
        assert refused_at < completed and idle_at < completed
        return {**result, "listener_refused_monotonic": refused_at, "idle_closed_monotonic": idle_at,
                "admitted_status": status, "admitted_body": body.decode(),
                "admitted_completed_monotonic": completed,
                "listener_refused_before_completion": True, "idle_closed_before_completion": True,
                "forced_cleanup": False}
    finally:
        idle.close()
        peer.close()


def stuck(guard, job, mode, io_listener):
    idle = socket.create_connection(("127.0.0.1", APP), timeout=2)
    peer = request(APP, b"/users/me")
    blocked = None
    try:
        job.marker(mode.upper() + " ADMITTED")
        if mode == "io":
            blocked, address = io_listener.accept()
        job.request_stop()
        result = job.exited()
        closed_at = wait_until(guard, lambda: peer_closed(peer), timeout=1)
        idle_closed = wait_until(guard, lambda: peer_closed(idle), timeout=1)
        io_closed = wait_until(guard, lambda: peer_closed(blocked), timeout=1) if blocked else None
        # launchd's negative last exit status proves termination by signal.
        assert result["platform_last_exit_status"] == -signal.SIGKILL, result
        assert GRACE <= result["stop_to_exit_seconds"] <= GRACE + TEARDOWN, result
        assert result["stop_to_reap_seconds"] <= GRACE + TEARDOWN, result
        assert time.monotonic() - job.requested <= GRACE + TEARDOWN
        assert refused(APP) and refused(ADMIN)
        assert "NATURAL EXIT READY" not in job.text()
        return {**result, "grace_expiry_monotonic": job.requested + GRACE, "platform_forced_signal": "SIGKILL",
                "admitted_peer_closed": bool(closed_at), "idle_peer_closed": bool(idle_closed),
                "blocked_io_peer_closed": bool(io_closed) if blocked else None,
                "peer_closure_observed_monotonic": time.monotonic(),
                "forced_cleanup": False,
                "adverse": "serial CPU may prevent signal callback/stop controls and listener/idle shutdown before platform exit" if mode == "cpu" else
                           "blocked IO retains the real Socket; logical cleanup is not guaranteed after SIGKILL"}
    finally:
        idle.close()
        peer.close()
        if blocked:
            blocked.close()


def tls_proof(guard, job, directory, row):
    # Disposable self-signed local trust, not a production certificate/auth claim.
    guard.command(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                   "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost",
                   "-keyout", directory / "key.pem", "-out", directory / "certificate.pem"])
    (directory / "key.pem").chmod(0o600)
    (directory / "body").mkdir()
    (directory / "proxy").mkdir()
    config = directory / "nginx.conf"
    config.write_text((HERE / "nginx.conf").read_text().replace("@STATE@", str(directory)))
    nginx = shutil.which("nginx")
    assert nginx, "nginx unavailable"
    guard.command([nginx, "-t", "-p", str(directory) + "/", "-c", config])
    proxy = Job(guard, directory, job.label + ".tls", [nginx, "-p", str(directory) + "/", "-c", config])
    row["tls_proxy"] = proxy.record
    row["rendered_tls_config"] = config.read_text()
    guard.evidence.save()
    rows = []
    try:
        wait_until(guard, lambda: not refused(TLS))
        context = ssl.create_default_context(cafile=str(directory / "certificate.pem"))
        cases = [(b"/health", 200, b'{"ok":true}'),
                 (b"/users/%37?tag=a%2Bb&tag=%252F&empty=&k=a+b", 200, b'{"id":7,"name":"Alice"}'),
                 (b"/users/%2537?tag=a&tag=b", 400, None),
                 (b"//users/7?tag=%37", 404, None),
                 (b"/users/../users/7?tag=a%2Bb", 404, None),
                 (b"/users/7/", 404, None)]
        for target, expected, expected_body in cases:
            with request(TLS, target, context=context, headers=[(b"x-test-raw-target", target)]) as peer:
                status, headers, body = read_response(peer)
            assert status == expected, (target, status, body)
            if expected_body is not None:
                assert body == expected_body, (target, body)
            rows.append({"origin_target_hex": target.hex(), "status": status, "body_hex": body.hex()})
        for method, target, body, extra, expected in (
            (b"GET", b"/users/me", b"", [], 200),
            (b"POST", b"/users", b'{"name":"Cara"}', [(b"content-type", b"application/json")], 201)):
            with request(TLS, target, context=context, method=method, body=body,
                         headers=[(b"x-test-raw-target", target), *extra]) as peer:
                status, headers, response = read_response(peer)
            assert status == expected
            if expected == 201:
                assert headers[b"location"] == b"/users/9" and response == b'{"id":9,"name":"Cara"}'
            rows.append({"method": method.decode(), "origin_target_hex": target.hex(),
                         "status": status, "body_hex": response.hex()})
        # Admin never reaches the private upstream: public /stop is application 404.
        with request(TLS, b"/stop", context=context, method=b"POST",
                     headers=[(b"x-test-raw-target", b"/stop")]) as peer:
            status, headers, body = read_response(peer)
        assert status == 404
        rows.append({"method": "POST", "origin_target_hex": b"/stop".hex(),
                     "status": status, "body_hex": body.hex()})
        with request(ADMIN, b"/stop", method=b"POST") as peer:
            assert read_response(peer)[0] == 200
        job.requested = time.monotonic()
        result = job.exited()
        assert result["platform_last_exit_status"] == 0
        exact = job.text().count("RAW TARGET EXACT")
        assert exact == 9, (exact, job.text())
        # Host logs can lag peer-visible writes; inspect only after actual owner/process exit.
        journal = (directory / "journal").read_bytes()
        assert journal == b"CLOSED\n"
        row["journal_hex"] = journal.hex()
        return {**result, "tls_rows": rows, "exact_raw_target_markers": exact,
                "admin_not_proxied": True, "certificate": "disposable explicitly trusted self-signed localhost certificate",
                "unmatched_paths": "root byte oracle observes unchanged targets before framework routing errors; 404 separately verifies slash/dot routing",
                "exclusions": "nginx rejects some malformed targets before Camber; no claim for malformed percent escapes, absolute-form, HTTP/2 or public CA trust"}
    finally:
        try:
            proxy.request_stop()
            proxy_exit = proxy.exited()
            assert proxy_exit["platform_last_exit_status"] == 0
        except BaseException as error:
            proxy.record["controlled_stop_failure"] = repr(error)
        finally:
            release = proxy.release()
            proxy.record["listener_refused_after_release"] = refused(TLS)
            guard.evidence.save()
        assert release["released"] and not release["forced_cleanup"]
        assert "controlled_stop_failure" not in proxy.record and refused(TLS)


def source_hashes():
    paths = sorted(HERE.glob("*")) + [HERE.parent / "users.bend", HERE.parent / "users_demo.bend"]
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in paths if path.is_file() and path.suffix in (".bend", ".c", ".js", ".py", ".plist", ".conf")}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lane", choices=["native", "javascript", "all"], default="all")
    parser.add_argument("--case", choices=["cooperative", "cpu", "io", "tls-proof", "all"], default="all")
    parser.add_argument("--output", type=Path, default=HERE / "results.json")
    args = parser.parse_args()
    results = {"started_ns": time.time_ns(), "invocation": [sys.executable, *sys.argv], "cwd": str(ROOT),
               "status": "running", "platform": platform.platform(), "source_sha256": source_hashes(),
               "boundary": "launchd-owned dedicated complete-users processes; observed kernel exit and platform reap",
               "grace_seconds": GRACE, "teardown_seconds": TEARDOWN, "cases": [], "commands": [],
               "platform_jobs": [], "guard_failures": [],
               "published": {"camber": "0.6.0.0", "http": "0.30.0.0", "wire": "0.4.5.0"}}
    evidence = Evidence(args.output, results)
    guard = None
    directory = None
    signal_source = None
    failure = None
    try:
        disk_floor()
        guard = Guard(evidence)
        results["bend_version"] = guard.command(["bend", "version"])
        if args.lane in ("javascript", "all"):
            results["bun_version"] = guard.command(["bun", "--version"])
        if args.case in ("tls-proof", "all"):
            results["nginx_version"] = guard.command(["nginx", "-v"])
        directory = Path(tempfile.mkdtemp(prefix="camber-launchd-"))
        results["owned_temporary_directory"] = str(directory)
        directory.chmod(0o700)
        for port in (APP, ADMIN, BLOCKING_IO, TLS):
            assert refused(port), ("port already owned", port)
        for lane in (["native", "javascript"] if args.lane == "all" else [args.lane]):
            binary = directory / ("users" if lane == "native" else "users.js")
            if lane == "javascript":
                signal_source = directory / "signals.c"
                shutil.copyfile(HERE / "signals.c", signal_source)
                signal_source.chmod(0o400)
                results["javascript_signal_source"] = {
                    "path": str(signal_source), "mode": "0400",
                    "sha256": hashlib.sha256(signal_source.read_bytes()).hexdigest(),
                    "backend": "installed Bun experimental bun:ffi cc, native image retained until process exit"}
                assert results["javascript_signal_source"]["sha256"] == results["source_sha256"]["camber/deploy/signals.c"]
                evidence.save()
            guard.command(["bend", HERE / "users.bend", "-o", binary], timeout=180)
            command = [binary, "--threads", "1", "--gpu", "off"] if lane == "native" else [shutil.which("bun"), binary]
            for mode in (["cooperative", "cpu", "io", "tls-proof"] if args.case == "all" else [args.case]):
                row = {"lane": lane, "mode": mode, "source_sha256": results["source_sha256"], "passed": False}
                results["cases"].append(row) # Persist before bootstrap or any cleanup can fail.
                evidence.save()
                case_dir = directory / f"{lane}-{mode}"
                case_dir.mkdir(mode=0o700)
                listener = None
                job = None
                try:
                    if mode == "io":
                        listener = socket.socket()
                        listener.bind(("127.0.0.1", BLOCKING_IO))
                        listener.listen(1)
                        listener.settimeout(2)
                    job = Job(guard, case_dir, f"org.bend-kit.camber.verify.{os.getpid()}.{results['started_ns']}.{lane}.{mode}",
                              [*command, APP, ADMIN, case_dir / "journal", mode])
                    row.update(pid=job.pid, parent_pid=job.parent, platform_job=job.record)
                    job.marker("READY DEDICATED USERS")
                    if mode == "cooperative":
                        row.update(cooperative(guard, job))
                        journal = (case_dir / "journal").read_bytes()
                        row["journal_hex"] = journal.hex()
                        assert journal == b"CLOSED\n"
                    elif mode in ("cpu", "io"):
                        row.update(stuck(guard, job, mode, listener))
                        journal = (case_dir / "journal").read_bytes()
                        row["journal_hex"] = journal.hex()
                        assert journal == b""
                    else:
                        row.update(tls_proof(guard, job, case_dir, row))
                    row["passed"] = True
                except BaseException as error:
                    row.update(passed=False, failure=repr(error))
                    raise
                finally:
                    if listener:
                        listener.close()
                    if job:
                        row["release"] = job.release() # Returns a failure receipt, never erases the row.
                        if not row["release"]["released"] or row["release"]["forced_cleanup"]:
                            row.update(passed=False, release_failed=True)
                    try:
                        row["released_ports"] = {str(port): refused(port) for port in (APP, ADMIN, BLOCKING_IO, TLS)}
                        if not all(row["released_ports"].values()):
                            row.update(passed=False, listeners_survived=True)
                    except BaseException as error:
                        row.update(passed=False, release_observation_failure=repr(error))
                    evidence.save()
                assert row["passed"], row
                print(f"{lane}/{mode}: launchd PID {row['pid']} exited/reaped; passing={row['passed']}", flush=True)
    except BaseException as error:
        failure = error
        results["failure"] = repr(error)
    finally:
        if guard:
            release = guard.close() # Does not raise before the final invocation receipt.
            if (release["guard_failure"] or release["forced_cleanup"]
                    or release.get("cleanup_failure") or release.get("surviving_observed_processes")):
                failure = failure or RuntimeError("guard/release failed; see durable receipt")
        if signal_source:
            try:
                digest = hashlib.sha256(signal_source.read_bytes()).hexdigest()
                results["javascript_signal_source"]["sha256_after"] = digest
                assert digest == results["javascript_signal_source"]["sha256"]
            except BaseException as error:
                results["javascript_signal_source_failure"] = repr(error)
                failure = failure or error
        results["source_sha256_after"] = source_hashes()
        if results["source_sha256_after"] != results["source_sha256"]:
            failure = failure or RuntimeError("sources changed during platform verification")
        jobs_released = all(job.get("release", {}).get("released") for job in results["platform_jobs"])
        results["all_platform_jobs_released"] = jobs_released
        if not jobs_released:
            failure = failure or RuntimeError("owned platform job release failed")
        if directory:
            survivors = results.get("guard_release", {}).get("surviving_observed_processes")
            if jobs_released and not survivors and not results.get("guard_release", {}).get("cleanup_failure"):
                try:
                    shutil.rmtree(directory) # Only this invocation's newly-created private tree.
                    results["owned_temporary_directory_removed"] = True
                except BaseException as error:
                    results["temporary_release_failure"] = repr(error)
                    failure = failure or error
            else:
                results["owned_temporary_directory_preserved_for_recovery"] = str(directory)
        results["finished_ns"] = time.time_ns()
        results["status"] = "failed" if failure else "passed"
        if failure:
            results["failure"] = repr(failure)
        evidence.save()
    if failure:
        raise RuntimeError(results["failure"]) from failure


if __name__ == "__main__":
    main()
