# IP address benchmark

This times `Netip.parse` + `Netip.show` and `Netip.prefix.parse` + `Netip.contains` on fixed IPv4, IPv6 and CIDR lists, in Bend, C (`inet_pton`/`inet_ntop`), Rust (`std::net`), and Python (`ipaddress`). Nothing resolves names: every call parses a literal.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, `rustc`, and `python3`. Variants build and run one after another. Binaries go to `out/`, which git ignores. `run.py` exits non-zero if a build fails, a variant exits non-zero or misses an op, or any two runs print different checksums for one op.

## Input

Each op runs 10,000 rounds over its lists; every file carries the same lists.

- **addr**: 40 strings. 20 are valid: IPv4, `::`, `::1`, upper-case and zero-padded hextets, a leftmost-tie and a longest zero run, a lone zero group (not compressed), `1::`, `::ffff:192.0.2.128` and `::ffff:c000:280` (both shown mixed), and `64:ff9b::192.0.2.33` (embedded IPv4 that is not mapped, shown in hex). 20 are invalid: empty, three or five octets, octet 256, leading zero, trailing space, an Arabic-Indic digit, a port, seven or nine hextets, `::` standing for no group (inside and after eight hextets), two `::`, a five-digit hextet, leading or trailing single colon, brackets, a zone, a short embedded IPv4, IPv4 before `::`. That makes 400,000 parses and 200,000 shows.
- **cidr**: 16 prefixes (10 valid, from `/0` to `/128`; 6 invalid: `/33`, `/129`, empty length, no address, two slashes, `-1`) against 15 probe addresses. Each round parses the 15 probes, then the 16 prefixes, then tests each valid prefix against every probe: 150,000 probe parses, 160,000 prefix parses, 1,500,000 contains.

The lists stay inside the ground every variant agrees on: no IPv4-compatible `::a.b.c.d` form (BSD `inet_ntop` prints it dotted, the others hex), no prefix with host bits set (Python `ip_network` rejects it), no zero-padded prefix length (Python accepts `/08`). Python `ipaddress` accepts an RFC 4007 zone (`fe80::1%en0`), while Darwin `inet_pton` accepts zones and leading-zero IPv4 octets. Both variants explicitly reject those inputs so they compare the same strict syntax.

Checksums are wrapping u32. **addr**: per string, `h = h*31 + 1` on a failed parse; else, `h = h*31 + 2`, then `h = h*31 + c` over each byte of the shown address. **cidr**: `h = h*3` on a failed prefix parse; else, per probe, `h = h*3 + 2` if the prefix contains it and `h*3 + 1` if not. An IPv4 prefix never contains an IPv6 address, nor the reverse. All four variants produced **1,796,747,072** for addr and **660,060,416** for cidr.

## Results

Apple M4 Pro (arm64), macOS 26.6.2, 2026-09-28 CDT. Median of three serial runs with `python3 run.py`. Times are ms for 10,000 rounds; `Nx` is the multiple of the fastest variant for that op.

| op | C | Rust | Python | Bend |
|---|---:|---:|---:|---:|
| addr | 53.6 (2.1x) | 25.3 (1.0x) | 1,294.5 (51.2x) | 146.5 (5.8x) |
| cidr | 15.5 (2.2x) | 7.1 (1.0x) | 839.5 (119.0x) | 126.4 (17.9x) |

Versions: Bend 2.0.32, Apple clang 17.0.0, rustc 1.91.0, Python 3.14.6.

## The calls

| language | addr | cidr |
|---|---|---|
| Bend | `Netip.parse`, `Netip.show` | `Netip.prefix.parse`, `Netip.contains` |
| C | `inet_pton` (`AF_INET`, then `AF_INET6`), `inet_ntop` | split on `/` by hand, `inet_pton`, byte-mask compare |
| Rust | `str::parse::<IpAddr>`, `to_string` | `split_once('/')`, `parse::<IpAddr>`, `u32`/`u128` mask compare |
| Python | `ipaddress.ip_address`, `str` | `ipaddress.ip_network`, `in` |

C and Rust have no CIDR type in their standard libraries, so they read the length by hand with Bend's rule: 1 to 3 digits, no leading zero, at most 32 or 128.

JavaScript is left out. Node's `net` module validates (`net.isIP`) and matches (`net.BlockList`) addresses but has no public call that returns a parsed address's text, and the WHATWG `URL` host serializer writes `::ffff:c000:280` without mixed notation.
