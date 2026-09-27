import pathlib
import subprocess
import sys
import tempfile
import time

HERE = pathlib.Path(__file__).resolve().parent
FRAME_CHECKSUM = 1321016000
HPACK_CHECKSUM = 5167000


def run(command, expected):
    start = time.perf_counter()
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    elapsed = time.perf_counter() - start
    checksum = int(result.stdout.strip())
    if checksum != expected:
        raise ValueError(f"{' '.join(map(str, command))}: checksum {checksum} != {expected}")
    return elapsed


def main():
    try:
        import hyperframe
        import hpack
    except ImportError as exc:
        raise SystemExit("Install h2 in this Python environment: python3 -m pip install h2") from exc

    with tempfile.TemporaryDirectory() as temp:
        c = pathlib.Path(temp) / "c"
        bend = pathlib.Path(temp) / "bend"
        flags = subprocess.check_output(["pkg-config", "--cflags", "--libs", "libnghttp2"], text=True).split()
        subprocess.run(["cc", "-O2", str(HERE / "bench.c"), *flags, "-o", str(c)], check=True)
        subprocess.run(["bend", str(HERE / "bench.bend"), "-o", str(bend)], check=True)
        hc = pathlib.Path(temp) / "hpack-c"
        hb = pathlib.Path(temp) / "hpack-bend"
        subprocess.run(["cc", "-O2", str(HERE / "hpack.c"), *flags, "-o", str(hc)], check=True)
        subprocess.run(["bend", str(HERE / "hpack.bend"), "-o", str(hb)], check=True)
        print("input: 10,000 HTTP/2 PING ACK frames; checksum:", FRAME_CHECKSUM)
        for label, command in (
            ("nghttp2 C session", [str(c)]),
            ("Python h2/hyperframe", [sys.executable, str(HERE / "bench.py")]),
            ("Bend frame codec", [str(bend)]),
        ):
            print(f"{label}: {run(command, FRAME_CHECKSUM):.4f}s; checksum {FRAME_CHECKSUM}")
        print("input: 1,000 RFC 7541 C.3.1 request blocks on one HPACK connection; checksum:", HPACK_CHECKSUM)
        for label, command in (
            ("nghttp2 C HPACK decoder", [str(hc)]),
            ("Python hpack decoder", [sys.executable, str(HERE / "decode_hpack.py")]),
            ("Bend HPACK decoder", [str(hb)]),
        ):
            print(f"{label}: {run(command, HPACK_CHECKSUM):.4f}s; checksum {HPACK_CHECKSUM}")


if __name__ == "__main__":
    main()
