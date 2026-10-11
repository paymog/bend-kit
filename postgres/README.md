# postgres

A Postgres client in Bend. Protocol 3.0, SCRAM-SHA-256, prepared queries, and a pool.

```bend
import bend-kit-postgres@0.1.0.2/postgres.bend as Pg
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
```

`postgres.bend` imports that bytes version, `bend-kit-wire@0.4.6.1`, and `bend-kit-dns@0.6.0.2`. `codec.bend` and `scram.bend` are part of this package. Callers use `postgres.bend`.

`config(host, port, user, pass, db)` builds a `Config`. The default step timeout is 10 seconds. Set `tls` on that config when the server must use TLS. If TLS is set and the server refuses SSL, the error is `NoTls`. There is no fallback to cleartext.

`connect` returns a `Conn`. `query(conn, sql, params)` is Parse, Bind, Describe, Execute, and Sync. Parameters are `Maybe<Bytes>`: `None` is SQL NULL, and `text` wraps a `String`. The result is text columns. A server error carries its SQLSTATE. The connection comes back beside the reply. `pool.get` borrows one.

`smoke.bend` expects a live server with TLS and SCRAM, and the `POSTGRES_*` variables. The laws cover the codec and SCRAM fixtures, not the socket.
