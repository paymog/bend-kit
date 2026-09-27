#!/usr/bin/env python3
"""Regex benchmark in Python (re). See README.md."""
import re
import sys
import time

SIZE = int(sys.argv[1]) if len(sys.argv) > 1 else 1 << 20
ONLY = sys.argv[2] if len(sys.argv) > 2 else None
REDOS_N = 100_000


def text(size: int) -> str:
    e, h = size - 50, size - 20
    return (
        "x" * e
        + "user@host.com"
        + "x" * (h - e - 13)
        + "helloworld12"
        + "x" * (size - h - 12)
    )


def chk_groups(m: re.Match | None, n: int) -> int:
    if m is None:
        return 0
    h = 0
    for i in range(n):
        span = m.span(i)
        if span[0] < 0:
            h = (h * 31) & 0xFFFFFFFF
        else:
            h = (h * 31 + span[0]) & 0xFFFFFFFF
            h = (h * 31 + span[1]) & 0xFFFFFFFF
    return h


def lap(name: str, t0: float, chk: int) -> None:
    ms = (time.perf_counter() - t0) * 1000
    print(f"{name}\t{ms:.3f}\t{chk}", flush=True)


def want(name: str) -> bool:
    return ONLY is None or ONLY == name


s = text(SIZE)
re_hello = re.compile(r"hello\w+")
re_email = re.compile(r"(\w+)@(\w+)\.com")
re_redos = re.compile(r"(a*)*b")
re_x = re.compile(r"x")
re_early = re.compile(r"(x)x")
re_live = re.compile(r"xy")

if want("is_match"):
    t0 = time.perf_counter()
    lap("is_match", t0, int(re_hello.search(s) is not None))

if want("is_match_early"):
    t0 = time.perf_counter()
    lap("is_match_early", t0, int(re_x.search(s) is not None))

if want("is_match_live"):
    t0 = time.perf_counter()
    lap("is_match_live", t0, int(re_live.search(s) is not None))

if want("find_captures"):
    t0 = time.perf_counter()
    lap("find_captures", t0, chk_groups(re_email.search(s), 3))

if want("find_early"):
    t0 = time.perf_counter()
    lap("find_early", t0, chk_groups(re_early.search(s), 2))

if want("redos"):
    t0 = time.perf_counter()
    lap("redos", t0, chk_groups(re_redos.search("a" * REDOS_N), 1))

if want("large"):
    s_large = "x" * 1000 + "y"
    re_large = re.compile(r"(?:x?){1000}y")
    t0 = time.perf_counter()
    lap("large", t0, chk_groups(re_large.search(s_large), 1))
