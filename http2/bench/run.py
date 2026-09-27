import pathlib
import subprocess
import sys
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent
EXPECTED = 1321016000


def run(command):
    start = time.perf_counter()
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    elapsed = time.perf_counter() - start
    checksum = int(result.stdout.strip())
    if checksum != EXPECTED:
        raise ValueError(f"{' '.join(map(str, command))}: checksum {checksum} != {EXPECTED}")
    return elapsed


def main():
    try:
        import hyperframe
    except ImportError as exc:
        raise SystemExit("Install h2 in this Python environment: python3 -m pip install h2") from exc

    with tempfile.TemporaryDirectory() as temp:
        c = pathlib.Path(temp) / "c"
        bend = pathlib.Path(temp) / "bend"
        flags = subprocess.check_output(["pkg-config", "--cflags", "--libs", "libnghttp2"], text=True).split()
        subprocess.run(["cc", "-O2", str(HERE / "bench.c"), *flags, "-o", str(c)], check=True)
        subprocess.run(["bend", str(HERE / "bench.bend"), "-o", str(bend)], check=True)
        print("input: 10,000 HTTP/2 PING ACK frames; checksum:", EXPECTED)
        for label, command in (
            ("nghttp2 C session", [str(c)]),
            ("Python h2/hyperframe", [sys.executable, str(HERE / "bench.py")]),
            ("Bend frame codec", [str(bend)]),
        ):
            print(f"{label}: {run(command):.4f}s; checksum {EXPECTED}")


if __name__ == "__main__":
    main()
