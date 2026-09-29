import Base
import ./sqlite.bend as Sqlite

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, message)

def reject(r: Result<&1, &1, U32 & String, U32>, message: String) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.pure(Unit, Unit{})
    case Done{v}:
      IO.die(Unit, 1, message)

def reject_unit(r: Result<&1, &1, U32 & String, Unit>, message: String) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.pure(Unit, Unit{})
    case Done{v}:
      IO.die(Unit, 1, message)

def blob_word(pair: Array<U32> & U32, len: U32) -> Bool:
  (words, first) = pair
  U32.is_eq(len, 3) && U32.is_eq(first, 197121)

def blob_ok(blob: U32 & Array<U32>) -> Bool:
  (len, words) = blob
  blob_word(Array.get(U32, words, 0), len)

def main() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32, Sqlite.db.open(":memory:"))
    +create : U32 <- IO.try(U32, Sqlite.stmt.prepare(db, "CREATE TABLE items (id INTEGER, name TEXT, data BLOB, optional TEXT)"))
    created : Bool <- IO.try(Bool, Sqlite.stmt.step(create))
    require(Bool.not(created), "CREATE returned a row")
    IO.try(Unit, Sqlite.stmt.finalize(create))
    +insert : U32 <- IO.try(U32, Sqlite.stmt.prepare(db, "INSERT INTO items VALUES (?, ?, ?, ?)"))
    IO.try(Unit, Sqlite.stmt.bind.int(insert, 1, 42))
    IO.try(Unit, Sqlite.stmt.bind.text(insert, 2, "café'; DROP TABLE items; --"))
    IO.try(Unit, Sqlite.stmt.bind.blob(insert, 3, 3, [197121 : U32*1n]))
    IO.try(Unit, Sqlite.stmt.bind.null(insert, 4))
    inserted : Bool <- IO.try(Bool, Sqlite.stmt.step(insert))
    require(Bool.not(inserted), "INSERT returned a row")
    IO.try(Unit, Sqlite.stmt.finalize(insert))
    +query : U32 <- IO.try(U32, Sqlite.stmt.prepare(db, "SELECT id, name, data, optional FROM items WHERE id = ?"))
    IO.try(Unit, Sqlite.stmt.bind.int(query, 1, 42))
    row : Bool <- IO.try(Bool, Sqlite.stmt.step(query))
    require(row, "SELECT missed inserted row")
    number : U32 <- IO.try(U32, Sqlite.stmt.column.int(query, 0))
    name : String <- IO.try(String, Sqlite.stmt.column.text(query, 1))
    blob : U32 & Array<U32> <- IO.try(U32 & Array<U32>, Sqlite.stmt.column.blob(query, 2))
    kind : U32 <- IO.try(U32, Sqlite.stmt.column.kind(query, 3))
    require(U32.is_eq(number, 42) && String.eq(name, "café'; DROP TABLE items; --") && blob_ok(blob) &&
      U32.is_eq(kind, 5), "selected columns differ")
    done : Bool <- IO.try(Bool, Sqlite.stmt.step(query))
    require(Bool.not(done), "SELECT returned extra rows")
    IO.try(Unit, Sqlite.stmt.reset(query))
    again : Bool <- IO.try(Bool, Sqlite.stmt.step(query))
    require(again, "reset lost bindings")
    busy : Result<&1, &1, U32 & String, Unit> <- Sqlite.db.close(db)
    reject_unit(busy, "closed a database with a live statement")
    IO.try(Unit, Sqlite.stmt.finalize(query))
    extra : Result<&1, &1, U32 & String, U32> <- Sqlite.stmt.prepare(db, "SELECT 1; SELECT 2")
    reject(extra, "multiple statements accepted")
    IO.try(Unit, Sqlite.db.close(db))
    stale : Result<&1, &1, U32 & String, U32> <- Sqlite.stmt.prepare(db, "SELECT 1")
    reject(stale, "closed database accepted a statement")
    IO.print("sqlite smoke ok")
