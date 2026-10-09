# dns

A DNS codec and host lookup. `query` and `answer` are pure. Lookup is `IO`.

```bend
import bend-kit-dns@0.6.0.1/dns.bend as Dns
```

`query(id, name)` builds a standard A query, or `None` when a label is empty or longer than 63 bytes. `answer(id, msg)` returns the first A record for that id, skipping CNAMEs before it.

`resolve(host)` returns the first address. `resolve.all(host)` returns every address in OS order, IPv6 and IPv4. A literal IP and `localhost` (`::1`, then `127.0.0.1`) do not call the OS. Other names use `getaddrinfo`.

`resolve.pure` and `resolve.all.pure` check `/etc/hosts`, then the first three nameservers in `/etc/resolv.conf`. `resolve.at(host, ns)` asks one server. A silent server is two attempts of 5 seconds, then the next server. The UDP path still asks for A records only.

`http@0.30.0.0` imports `bend-kit-dns@0.5.0.0`, not this version. Pass addresses into that `http` from `0.5.0.0` if the types have to match. This package imports `bend-kit-wire@0.4.3.0` and `bend-kit-bytes@0.3.2.0`.

Proofs cover `query`, `answer`, and the pure resolver. They do not cover `effs/dns.c` and `effs/dns.js`.
