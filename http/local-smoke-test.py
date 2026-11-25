#!/usr/bin/env python3
"""Inject tool failures while exercising the smoke harness and checker cleanup."""

import ast
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile

HTTP = Path(__file__).resolve().parent

TOOL = f"#!{sys.executable}\n" + r'''
import os
from pathlib import Path
import shutil
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
case = os.environ["SMOKE_CASE"]
if name == "bend":
    if args == ["version"]:
        raise SystemExit(0)
    source = Path(args[0]).stem
    output = Path(args[args.index("-o") + 1])
    lane = "js" if output.suffix == ".js" else "native"
    with open(os.environ["SMOKE_EVENTS"], "a") as log:
        log.write(f"compile {lane} {source}\n")
    if case == f"{lane}:{source}:compile":
        raise SystemExit(23)
    shutil.copyfile(os.environ["SMOKE_SERVER"], output)
    output.chmod(0o755)
elif name == "bun":
    os.execv(args[0], args)
elif name == "curl":
    lane = Path(os.environ["SMOKE_LANE"]).read_text()
    if "--data-binary" in args:
        print("wrong" if case == f"{lane}:demo:serve" else "/hi")
    elif "--http1.1" in args:
        print("Re-using existing connection")
    elif "Transfer-Encoding: gzip" in args:
        print("200" if case == f"{lane}:demo:transfer" else "400")
    else:
        print("200" if case == f"{lane}:demo:header" else "431")
elif name == "sleep":
    pass
elif name == "python3":
    args = [arg for arg in args if arg != "-B"]
    if args[0].endswith("rss-check.py"):
        args = args[1:]
        os.execvp(args[0], args)
    if args[0] == "-":
        lane = Path(os.environ["SMOKE_LANE"]).read_text()
        assert case != f"{lane}:demo:http10", "injected HTTP/1.0 assertion"
    elif args[0] == "reject_check.py":
        lane = Path(os.environ["SMOKE_LANE"]).read_text()
        assert case != f"{lane}:demo:reject", "injected rejection assertion"
    else:
        os.execv(os.environ["SMOKE_PYTHON"], [os.environ["SMOKE_PYTHON"], *args])
'''

SERVER = f'''#!{sys.executable}
import os
from pathlib import Path
import time

path = Path(__file__)
lane = "js" if path.suffix == ".js" else "native"
source = path.stem
with open(os.environ["SMOKE_PIDS"], "a") as log:
    log.write(f"{{os.getpid()}}\\n")
Path(os.environ["SMOKE_LANE"]).write_text(lane)
if os.environ["SMOKE_CASE"] != f"{{lane}}:{{source}}:ready":
    print("READY 12345", flush=True)
while True:
    time.sleep(60)
'''


def fixture_checker(source, target):
    tree = ast.parse(source.read_text())
    # Keep the real entry point, READY reader, and finally block.
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name == "run":
            node.body = ast.parse(
                'import os\n'
                'from pathlib import Path\n'
                'lane = Path(os.environ["SMOKE_LANE"]).read_text()\n'
                f'assert os.environ["SMOKE_CASE"] != lane + ":{source.stem.removesuffix("_check")}_demo:assert", "injected checker assertion"\n'
            ).body
    target.write_text(ast.unparse(ast.fix_missing_locations(tree)))


def run_case(root, case):
    pids = root / "pids"
    events = root / "events"
    pids.write_text("")
    events.write_text("")
    env = dict(os.environ, PATH=f"{root / 'bin'}:{os.environ['PATH']}",
               SMOKE_CASE=case, SMOKE_PIDS=str(pids), SMOKE_EVENTS=str(events),
               SMOKE_LANE=str(root / "lane"), SMOKE_SERVER=str(root / "server"),
               SMOKE_PYTHON=sys.executable)
    try:
        result = subprocess.run(["bash", str(root / "http/local-smoke.sh")],
                                env=env, capture_output=True, text=True, timeout=45)
        assert (result.returncode == 0) == (case == "success"), (case, result.stdout, result.stderr)
        compiled = events.read_text().splitlines()
        order = [f"compile {lane} {source}" for lane in ("native", "js")
                 for source in ("demo", "stream_demo", "write_demo")]
        if case == "success":
            assert compiled == order, compiled
            assert len(pids.read_text().splitlines()) == 6
        else:
            lane, source, failure = case.split(":")
            count = order.index(f"compile {lane} {source}") + 1
            assert compiled == order[:count], (case, compiled)
            assert len(pids.read_text().splitlines()) == count - (failure == "compile"), case
        for pid in pids.read_text().splitlines():
            try:
                os.kill(int(pid), 0)
            except ProcessLookupError:
                continue
            raise AssertionError(f"{case}: fixture server {pid} is still alive")
    finally:
        for pid in pids.read_text().splitlines():
            try:
                os.kill(int(pid), signal.SIGKILL)
            except ProcessLookupError:
                pass
    print(f"PASS {case}")


def main():
    with tempfile.TemporaryDirectory(prefix="http-smoke-test-") as temporary:
        root = Path(temporary)
        (root / "http").mkdir()
        (root / "bin").mkdir()
        shutil.copyfile(HTTP / "local-smoke.sh", root / "http/local-smoke.sh")
        shutil.copyfile(HTTP / "smoke_ready.py", root / "http/smoke_ready.py")
        for name in ("stream_check.py", "write_check.py"):
            fixture_checker(HTTP / name, root / "http" / name)
        (root / "server").write_text(SERVER)
        (root / "tool").write_text(TOOL)
        (root / "tool").chmod(0o755)
        for name in ("bend", "bun", "curl", "python3", "sleep"):
            (root / "bin" / name).symlink_to(root / "tool")
        run_case(root, "success")
        for lane in ("native", "js"):
            for source in ("demo", "stream_demo", "write_demo"):
                for failure in ("compile", "ready"):
                    run_case(root, f"{lane}:{source}:{failure}")
            for failure in ("serve", "http10", "transfer", "header", "reject"):
                run_case(root, f"{lane}:demo:{failure}")
            for source in ("stream_demo", "write_demo"):
                run_case(root, f"{lane}:{source}:assert")


if __name__ == "__main__":
    main()
