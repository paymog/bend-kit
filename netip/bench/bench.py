"""IP address benchmark in Python with ipaddress (see README.md)."""
import ipaddress
import time

ROUNDS = 10000
M = 0xFFFFFFFF

ADDRS = [
    "0.0.0.0",
    "127.0.0.1",
    "192.168.1.254",
    "255.255.255.255",
    "10.0.0.1",
    "::",
    "::1",
    "2001:db8::1",
    "2001:DB8:0:0:0:0:0:1",
    "2001:0db8:0000:0000:0001:0000:0000:0001",
    "fe80::1:2:3:4",
    "1:0:0:2:0:0:0:3",
    "1:2:3:4:5:6:7:8",
    "1::",
    "2001:db8:0:1:1:1:1:1",
    "::ffff:192.0.2.128",
    "::ffff:c000:280",
    "64:ff9b::192.0.2.33",
    "ff02::fb",
    "2001:db8:85a3::8a2e:370:7334",
    "",
    "1.2.3",
    "1.2.3.4.5",
    "256.1.1.1",
    "01.2.3.4",
    "1.2.3.4 ",
    "1.2.3.\u0664",
    "1.2.3.4:80",
    "1:2:3:4:5:6:7",
    "1:2:3:4:5:6:7:8:9",
    "1:2:3:4:5:6:7::8",
    "1::2::3",
    "12345::",
    "1:2:3:4:5:6:7:",
    ":1:2:3:4:5:6:7",
    "[::1]",
    "fe80::1%en0",
    "::ffff:1.2.3",
    "1.2.3.4::1",
    "1:2:3:4:5:6:7:8::",
]

PREFIXES = [
    "10.0.0.0/8",
    "192.168.0.0/16",
    "192.168.1.0/24",
    "0.0.0.0/0",
    "203.0.113.7/32",
    "2001:db8::/32",
    "fe80::/10",
    "::/0",
    "::1/128",
    "2001:db8:85a3::/48",
    "10.0.0.0/33",
    "2001:db8::/129",
    "10.0.0.0/",
    "/8",
    "10.0.0.0/8/8",
    "10.0.0.0/-1",
]

PROBES = [
    "10.1.2.3",
    "11.0.0.1",
    "192.168.1.77",
    "192.168.2.1",
    "203.0.113.7",
    "203.0.113.8",
    "8.8.8.8",
    "2001:db8::1",
    "2001:db8:85a3::8a2e:370:7334",
    "2001:db9::1",
    "fe80::1",
    "febf:ffff::1",
    "fec0::1",
    "::1",
    "::",
]


def parse(s):
    if "%" in s:  # ipaddress accepts an RFC 4007 zone; the other variants reject it
        return None
    try:
        return ipaddress.ip_address(s)
    except ValueError:
        return None


def network(s):
    try:
        return ipaddress.ip_network(s)
    except ValueError:
        return None


def addr_rounds():
    h = 0
    for _ in range(ROUNDS):
        for s in ADDRS:
            a = parse(s)
            if a is None:
                h = (h * 31 + 1) & M
                continue
            h = (h * 31 + 2) & M
            for c in str(a):
                h = (h * 31 + ord(c)) & M
    return h


def cidr_rounds():
    h = 0
    for _ in range(ROUNDS):
        ps = [a for a in map(parse, PROBES) if a is not None]
        for s in PREFIXES:
            n = network(s)
            if n is None:
                h = (h * 3) & M
                continue
            for a in ps:
                h = (h * 3 + (2 if a in n else 1)) & M
    return h


for op, f in (("addr", addr_rounds), ("cidr", cidr_rounds)):
    t0 = time.perf_counter()
    h = f()
    print(f"{op}\t{(time.perf_counter() - t0) * 1000:.3f}\t{h}")
