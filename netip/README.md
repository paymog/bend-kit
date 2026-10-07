# IP addresses and prefixes

```bend
import bend-kit-netip@0.1.0.0/netip.bend as Netip
```


`netip.bend` parses IPv4 and IPv6 literals into copyable `Addr` values. `parse` returns `None` for malformed input; it does not resolve host names or read ports. IPv4 accepts four decimal octets without leading zeros. IPv6 accepts the RFC 4291 colon and trailing dotted-decimal forms; no brackets, zone identifiers or port suffixes. `show` emits canonical RFC 5952 lowercase text, compressing the longest leftmost run of at least two zero hextets. IPv4-mapped IPv6 uses `::ffff:192.0.2.1` notation. `eq` compares addresses by family and bits, not by spelling.

`prefix.parse("192.0.2.1/24")` accepts prefix lengths 0 to 32 for IPv4 and 0 to 128 for IPv6. `contains(prefix, addr)` tests the leading network bits, including first and last members, and rejects a different address family. `prefix.show` preserves the supplied address bits instead of rewriting them to the network address; for example `192.0.2.1/24` remains `192.0.2.1/24`. Construct `Prefix` with valid bits or use `prefix.parse` to validate a text prefix. It does not implement routing or subnet enumeration.

Run `../scripts/check.sh netip` for laws, proofs and boundary fixtures. Run `python3 bench/run.py` for the serial cross-language benchmark.
