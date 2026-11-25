"""Disposable GitHub-hosted system-domain deployment support."""
import hashlib
import os
import platform
import shutil
import stat
import time
from pathlib import Path


class SystemHost:
    def __init__(self, guard):
        self.guard = guard
        self.record = {"account_created": False, "group_created": False, "paths": []}
        guard.evidence.invocation["system_deployment"] = self.record
        guard.evidence.save()
        if (os.geteuid() != 0 or platform.system() != "Darwin" or platform.machine() != "arm64"
                or os.environ.get("GITHUB_ACTIONS") != "true"
                or os.environ.get("RUNNER_ENVIRONMENT") != "github-hosted"):
            raise RuntimeError("system acceptance requires root on a disposable GitHub-hosted macOS arm64 runner")
        self.name = f"_camber_{os.getpid()}_{time.time_ns()}"
        used = set()
        for kind, field in (("Users", "UniqueID"), ("Groups", "PrimaryGroupID")):
            rows = guard.command(["dscl", ".", "-list", f"/{kind}", field])["stdout"]
            used.update(int(line.split()[-1]) for line in rows.splitlines() if line.split()[-1].lstrip("-").isdigit())
        self.uid = next(number for number in range(400, 500) if number not in used)
        self.record.update(account=self.name, uid=self.uid, gid=self.uid)
        guard.evidence.save()

    def provision(self):
        # Record intent first so a partial dscl failure still enters cleanup.
        for kind, marker, fields in (
            ("Groups", "group_created", {"PrimaryGroupID": str(self.uid)}),
            ("Users", "account_created", {"UniqueID": str(self.uid), "PrimaryGroupID": str(self.uid),
                                            "UserShell": "/usr/bin/false", "NFSHomeDirectory": "/var/empty",
                                            "IsHidden": "1", "Password": "*"})):
            path = f"/{kind}/{self.name}"
            self.record[marker] = True
            self.guard.evidence.save()
            self.guard.command(["dscl", ".", "-create", path])
            for field, value in fields.items():
                self.guard.command(["dscl", ".", "-create", path, field, value])
        self.record["account_attributes"] = self.guard.command(
            ["dscl", ".", "-read", f"/Users/{self.name}", "UniqueID", "PrimaryGroupID", "UserShell", "NFSHomeDirectory", "IsHidden"])["stdout"]
        self.guard.evidence.save()

    def inspect(self, path, uid=0, mode=None):
        path = Path(path)
        info = path.lstat()
        row = {"path": str(path), "uid": info.st_uid, "gid": info.st_gid,
               "mode": oct(stat.S_IMODE(info.st_mode)), "symlink": stat.S_ISLNK(info.st_mode)}
        if path.is_file() and not row["symlink"]:
            row["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        self.record["paths"].append(row)
        self.guard.evidence.save()
        assert not row["symlink"] and info.st_uid == uid, row
        assert not stat.S_IMODE(info.st_mode) & 0o022, row
        if mode is not None:
            assert stat.S_IMODE(info.st_mode) == mode, row
        writable = self.guard.command(["sudo", "-n", "-u", self.name, "/bin/test", "-w", path], check=False)
        assert (writable["status"] == 0) == (uid == self.uid), (row, writable)
        return row

    def install(self, source, directory, name):
        destination = directory / name
        shutil.copyfile(source, destination)
        destination.chmod(0o555)
        self.inspect(destination, mode=0o555)
        self.inspect(directory, mode=0o755)
        return destination

    def state(self, path):
        path.mkdir(mode=0o700)
        os.chown(path, self.uid, self.uid)
        self.inspect(path, uid=self.uid, mode=0o700)
        return path

    def job_config(self, config, state):
        config.update(UserName=self.name, GroupName=self.name, WorkingDirectory=str(state))
        for key in ("StandardOutPath", "StandardErrorPath"):
            config[key] = str(state / Path(config[key]).name)

    def identity(self, pid):
        result = self.guard.command(["ps", "-o", "uid=,gid=", "-p", pid])["stdout"]
        observed = list(map(int, result.split()))
        self.record.setdefault("process_credentials", []).append({"pid": pid, "uid_gid": observed})
        self.guard.evidence.save()
        assert observed == [self.uid, self.uid], observed

    def verify_paths(self):
        for before in list(self.record["paths"]):
            after = self.inspect(before["path"], uid=before["uid"], mode=int(before["mode"], 8))
            if "sha256" in before:
                assert after["sha256"] == before["sha256"], (before, after)

    def release(self, safe):
        if not safe:
            self.record["account_preserved_for_recovery"] = True
            self.guard.evidence.save()
            raise RuntimeError("owned jobs or files remain; preserve the dedicated account")
        for kind, marker in (("Users", "account_created"), ("Groups", "group_created")):
            if self.record[marker]:
                path = f"/{kind}/{self.name}"
                self.guard.command(["dscl", ".", "-delete", path], cleanup=True)
                absent = self.guard.command(["dscl", ".", "-read", path], check=False, cleanup=True)
                assert absent["status"] != 0, absent
                self.record[marker.replace("created", "removed")] = True
                self.guard.evidence.save()
