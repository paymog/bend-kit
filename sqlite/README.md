# SQLite

Prepared statements over the system `libsqlite3` on native and Bun targets. The library is loaded at run time. Set `BEND_LIBSQLITE` to a library path to override the system library. No SQLite code is bundled.

```bend
import Base
import ./sqlite.bend as Sqlite

def main() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32, Sqlite.db.open(":memory:"))
    +statement : U32 <- IO.try(U32, Sqlite.stmt.prepare(db, "SELECT ?"))
    IO.try(Unit, Sqlite.stmt.bind.int(statement, 1, 42))
    row : Bool <- IO.try(Bool, Sqlite.stmt.step(statement))
    value : U32 <- IO.try(U32, Sqlite.stmt.column.int(statement, 0))
    IO.print(U32.show(value))
    IO.try(Unit, Sqlite.stmt.finalize(statement))
    IO.try(Unit, Sqlite.db.close(db))
```

`db.open` opens or creates a file; `":memory:"` creates an in-memory database. Prepare accepts exactly one SQL statement. Bind values with `stmt.bind.int`, `.text`, `.blob`, or `.null`; bind indexes start at 1. `stmt.step` returns `True` for a row and `False` when done. Read columns only on a row; column indexes start at 0. `stmt.column.kind` returns SQLite's kind codes: 1 integer, 2 float, 3 text, 4 blob, 5 null. Integer methods accept unsigned 32-bit values; read a wider or negative integer as text. Blob arguments and results use `(byte count, Array<U32>)`, four octets per word in little-endian order. `stmt.reset` retains bindings.

Database and statement IDs are opaque. Finalize every statement before closing its database; closing with live statements returns `SQLITE_BUSY`. Every effect returns `Result` with a SQLite error code and message. Handles and SQLite's filesystem, transaction, and SQL semantics are foreign trust assumptions: Bend proofs cannot verify them. The smoke check covers parameter binding, a table insert and select, reset, column reads, invalid handles, and multiple-statement rejection.
