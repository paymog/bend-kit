# Prepared SQLite statements through libsqlite3. Source: https://github.com/paymog/bend-kit/tree/main/sqlite
import Base

# Handles are opaque U32 IDs. Close each database after finalizing all its statements.
# Every effect returns (SQLite error code, message) on failure.
# BEND_LIBSQLITE selects a custom libsqlite3 path.
def db.open(path: String) -> IO(Result<&1, &1, U32 & String, U32>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"

def db.close(db: U32) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"

# Exactly one SQL statement is accepted; use bind operations for values.
def stmt.prepare(db: U32, sql: String) -> IO(Result<&1, &1, U32 & String, U32>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"

def stmt.finalize(stmt: U32) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"

# Bind positions start at 1. Integer values are unsigned 32-bit.
def stmt.bind.int(stmt: U32, index: U32, value: U32) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"

def stmt.bind.text(stmt: U32, index: U32, text: String) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"

def stmt.bind.null(stmt: U32, index: U32) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"

# Blob octets are packed four per U32, least-significant byte first.
def stmt.bind.blob(stmt: U32, index: U32, len: U32, words: Array<U32>) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"

# True means a row is available; False means no more rows.
def stmt.step(stmt: U32) -> IO(Result<&1, &1, U32 & String, Bool>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"

def stmt.reset(stmt: U32) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"

# Column indexes start at 0. Read columns only after a True step.
# SQLite kinds: 1 integer, 2 float, 3 text, 4 blob, 5 null.
def stmt.column.kind(stmt: U32, index: U32) -> IO(Result<&1, &1, U32 & String, U32>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"

def stmt.column.int(stmt: U32, index: U32) -> IO(Result<&1, &1, U32 & String, U32>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"

def stmt.column.text(stmt: U32, index: U32) -> IO(Result<&1, &1, U32 & String, String>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"

def stmt.column.blob(stmt: U32, index: U32) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/sqlite.c"
  import "./effs/sqlite.js"
