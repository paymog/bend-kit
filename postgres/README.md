# postgres

A Postgres client in Bend. Protocol 3.0, SCRAM-SHA-256, prepared queries, and a pool.

```bend
import bend-kit-postgres@0.3.1.0/postgres.bend as Pg
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
```

`postgres.bend` imports that bytes version, `bend-kit-wire@0.4.8.0`, and `bend-kit-dns@0.7.1.0`. `scram.bend` also imports `bend-kit-crypto@0.2.2.2`. `codec.bend` and `scram.bend` are part of this package. Callers use `postgres.bend`.

`config(host, port, user, pass, db)` builds a `Config`. TLS is on by default. The default step timeout is 10 seconds. Keep `tls` set when the server must use TLS. If the server refuses SSL, the error is `NoTls`. The client does not switch to cleartext.

`connect` returns a `Result` with a `Conn` on success. `query(conn, sql, params)` sends Parse, Bind, Describe, Execute, and Sync messages. Parameters have type `Maybe<&1, Bytes.Bytes>`. `None` means SQL NULL. `text` makes a text parameter from a `String`. Results contain text columns. A server error carries its SQLSTATE. A successful query returns the connection beside the reply. `pool.get` borrows a connection. `pool.put` returns it to the pool.

`smoke.bend` expects a live server with TLS and SCRAM, and the `POSTGRES_*` variables. The laws cover the codec and SCRAM fixtures, not the socket.
