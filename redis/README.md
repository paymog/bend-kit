# redis

A Redis and Valkey client. RESP3 over TCP or TLS, with pipelining and a pool.

```bend
import bend-kit-redis@0.3.1.0/redis.bend as Redis
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
```

`redis.bend` imports that bytes version, `bend-kit-wire@0.4.8.0`, and `bend-kit-dns@0.7.1.0`. A `Conn` is affine. `command`, `pipeline`, `get`, `set`, and `incr` return a `Result`. On success, it contains the connection beside the value.

`Config` is `Config{host, port, tls, user, pass, db, ms}`. `ms` bounds connect and read. `0` means no deadline. `connect` sends `HELLO 3`. It includes `AUTH` in that command when the password is not empty. It then sends `SELECT` when `db` is not zero. TLS uses `wire` and checks the certificate and host name.

`encode` and `decode` are the RESP3 codec. Integers use two `U32` words for a signed 64-bit value. `pool.get` takes a connection from the pool or opens one. Return it with `pool.put` when you are done.

Pub/sub, cluster, sentinel, and client-side caching are not in this version. `smoke.bend` uses database 9 and `FLUSHDB` against a live server.
