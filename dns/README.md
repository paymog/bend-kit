# dns

A DNS codec and host lookup. `query` and `answer` are pure. Lookup is `IO`.

```bend
import bend-kit-dns@0.7.1.0/dns.bend as Dns
```

`query(id, name)` builds a standard A query, or `None` for an empty label, a label longer than 63 bytes, a non-ASCII label, or a name longer than 255 bytes in wire form (RFC 1035 §2.3.4). A final dot is accepted. `answer(id, msg)` returns the first A record for that id, skipping CNAMEs before it.

`resolve(host)` returns the first address. `resolve.all(host)` returns every address in OS order, IPv6 and IPv4. A literal IP and `localhost` (`::1`, then `127.0.0.1`) do not call the OS. Other names use `getaddrinfo`.

`resolve.pure` and `resolve.all.pure` check `/etc/hosts`, then the first three nameservers in `/etc/resolv.conf`. `resolve.at(host, ns)` asks one server. A silent server is two attempts of 5 seconds, then the next server. The UDP path still asks for A records only.

This package imports `bend-kit-wire@0.4.8.0` and `bend-kit-bytes@0.3.3.0`.

Proofs cover concrete fixtures for `query`, `answer`, nameserver parsing, hosts-file parsing, and literal addresses. They do not prove all resolver behavior or cover `effs/dns.c` and `effs/dns.js`.

| def | returns |
|---|---|
| `hosts.all(+name: String, text: String) -> List<&2, String>` | All matching addresses from hosts-file text, in file order. Pass a lowercase name. |
