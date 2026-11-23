#!/usr/bin/env python3
"""Run one command with a 20 GiB process-tree RSS ceiling."""
import os
import signal
import subprocess
import sys
import time

CEILING_KIB = 20 * 1024 * 1024


def run(command):
    process = subprocess.Popen(command, start_new_session=True)
    peak = 0
    exceeded = False
    try:
        while process.poll() is None:
            rows = subprocess.check_output(['ps', '-axo', 'pid=,ppid=,rss='], text=True)
            entries = [tuple(map(int, line.split())) for line in rows.splitlines()]
            descendants = {process.pid}
            while True:
                children = {pid for pid, ppid, rss in entries if ppid in descendants}
                if children <= descendants:
                    break
                descendants.update(children)
            rss = sum(rss for pid, ppid, rss in entries if pid in descendants)
            peak = max(peak, rss)
            if rss > CEILING_KIB:
                exceeded = True
                os.killpg(process.pid, signal.SIGKILL)
                break
            time.sleep(0.1)
    finally:
        if process.returncode is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        status = process.wait()
    print(f'peak process-tree RSS: {peak} KiB; ceiling: {CEILING_KIB} KiB', flush=True)
    return 1 if exceeded else status


if __name__ == '__main__':
    sys.exit(run(sys.argv[1:]))
