# Leveled, structured logging: a logger value, key-value fields, and logfmt or JSON-lines output. Source: https://github.com/paymog/bend-kit/tree/main/notch
import Base
# bend-kit-time@0.1.0.0
import 0x3bfb4ae4d3b87b90f01bfcd298211455/time.bend as Time

type Level is Data:
  Debug{}
  Info{}
  Warn{}
  Error{}

type Value is Data:
  Str{s: String}
  Num{n: U32}
  Flag{b: Bool}

type Field is Data:
  Field{key: String, val: Value}

# Text is logfmt, as Go's slog TextHandler writes it. Json is one object per line.
type Format is Data:
  Text{}
  Json{}

# ctx holds the fields from with, oldest first. A line puts them before its own fields.
type Logger is Data:
  Logger{min: Level, format: Format, ctx: List<&2, Field>}

# Levels
# ------

def Level.rank(l: Level) -> Nat:
  match l:
    case Debug{}:
      0n
    case Info{}:
      1n
    case Warn{}:
      2n
    case Error{}:
      3n

def Level.name(l: Level) -> String:
  match l:
    case Debug{}:
      "DEBUG"
    case Info{}:
      "INFO"
    case Warn{}:
      "WARN"
    case Error{}:
      "ERROR"

# Loggers and fields
# ------------------

def text(min: Level) -> Logger:
  Logger{min, Text{}, Nil{}}

def json(min: Level) -> Logger:
  Logger{min, Json{}, Nil{}}

# A logger that adds fs to every line, after the fields it already adds.
def with(lg: Logger, fs: List<&2, Field>) -> Logger:
  match lg:
    case Logger{m, f, c}:
      Logger{m, f, List.append(&2, Field, c, fs)}

def enabled(lg: Logger, lvl: Level) -> Bool:
  match lg:
    case Logger{m, f, c}:
      Nat.is_ge(Level.rank(lvl), Level.rank(m))

def str(k: String, v: String) -> Field:
  Field{k, Str{v}}

def num(k: String, n: U32) -> Field:
  Field{k, Num{n}}

def flag(k: String, b: Bool) -> Field:
  Field{k, Flag{b}}

# Rendering
# ---------

def hex(+n: U32) -> Char:
  Chr{Bool.pick(U32, U32.is_lt(n, 10), (48 + n : U32), (87 + n : U32))}

def esc.ctl(ctl: Bool, +c: U32, rest: String) -> String:
  match ctl:
    case True{}:
      SCon{Chr{92}, SCon{'u', SCon{'0', SCon{'0', SCon{hex(U32.shrn(c, 4n)),
        SCon{hex((c .&. 15 : U32)), rest}}}}}}
    case False{}:
      SCon{Chr{c}, rest}

# JSON (RFC 8259 §7): quote, backslash and control chars are escaped.
def esc.c(+c: U32, rest: String) -> String:
  match c:
    case 34:
      SCon{Chr{92}, SCon{Chr{34}, rest}}
    case 92:
      SCon{Chr{92}, SCon{Chr{92}, rest}}
    case 10:
      SCon{Chr{92}, SCon{'n', rest}}
    case 13:
      SCon{Chr{92}, SCon{'r', rest}}
    case 9:
      SCon{Chr{92}, SCon{'t', rest}}
    case _:
      esc.ctl(U32.is_lt(c, 32), c, rest)

def esc(s: String, rest: String) -> String:
  match s:
    case SNil{}:
      rest
    case SCon{Chr{x}, t}:
      esc.c(x, esc(t, rest))

def quote(s: String) -> String:
  SCon{Chr{34}, esc(s, SCon{Chr{34}, SNil{}})}

# A bare logfmt token has no whitespace, controls, '=', quote or DEL.
def bare.c(+c: U32) -> Bool:
  U32.is_lt(32, c) && U32.is_ne(c, 61) && U32.is_ne(c, 34) && U32.is_ne(c, 127) &&
    U32.is_ne(c, 133) && U32.is_ne(c, 160) && U32.is_ne(c, 5760) &&
    Bool.not(Bool.and(U32.is_ge(c, 8192), U32.is_le(c, 8202))) &&
    Bool.not(Bool.and(U32.is_ge(c, 8232), U32.is_le(c, 8233))) &&
    U32.is_ne(c, 8239) && U32.is_ne(c, 8287) && U32.is_ne(c, 12288)

def bare.go(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{x}, t}:
      Bool.and(bare.c(x), bare.go(t))

def bare(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{h, t}:
      bare.go(SCon{h, t})

def tq.if(ok: Bool, s: String) -> String:
  match ok:
    case True{}:
      s
    case False{}:
      quote(s)

# A logfmt key or string value: bare when it can be, else a JSON string.
def tq(+s: String) -> String:
  tq.if(bare(s), s)

def Bool.word(b: Bool) -> String:
  match b:
    case True{}:
      "true"
    case False{}:
      "false"

def Value.text(v: Value) -> String:
  match v:
    case Str{s}:
      tq(s)
    case Num{n}:
      U32.show(n)
    case Flag{b}:
      Bool.word(b)

def Value.json(v: Value) -> String:
  match v:
    case Str{s}:
      quote(s)
    case Num{n}:
      U32.show(n)
    case Flag{b}:
      Bool.word(b)

def fields.text(fs: List<&2, Field>) -> String:
  match fs:
    case Nil{}:
      ""
    case Con{Field{k, v}, t}:
      " " ++ tq(k) ++ "=" ++ Value.text(v) ++ fields.text(t)

def fields.json(fs: List<&2, Field>) -> String:
  match fs:
    case Nil{}:
      ""
    case Con{Field{k, v}, t}:
      "," ++ quote(k) ++ ":" ++ Value.json(v) ++ fields.json(t)

def time.text(t: Maybe<&2, String>) -> String:
  match t:
    case None{}:
      ""
    case Some{s}:
      "time=" ++ tq(s) ++ " "

def time.json(t: Maybe<&2, String>) -> String:
  match t:
    case None{}:
      ""
    case Some{s}:
      quote("time") ++ ":" ++ quote(s) ++ ","

def render.as(f: Format, t: Maybe<&2, String>, lvl: Level, msg: String,
  fs: List<&2, Field>) -> String:
  match f:
    case Text{}:
      time.text(t) ++ "level=" ++ Level.name(lvl) ++ " msg=" ++ tq(msg) ++ fields.text(fs)
    case Json{}:
      "{" ++ time.json(t) ++ quote("level") ++ ":" ++ quote(Level.name(lvl)) ++ "," ++
        quote("msg") ++ ":" ++ quote(msg) ++ fields.json(fs) ++ "}"

# One line, without its newline, whatever the level. t is the time text; None leaves it out.
def render(lg: Logger, t: Maybe<&2, String>, lvl: Level, msg: String,
  fs: List<&2, Field>) -> String:
  match lg:
    case Logger{m, f, c}:
      render.as(f, t, lvl, msg, List.append(&2, Field, c, fs))

def line.if(on: Bool, lg: Logger, t: Maybe<&2, String>, lvl: Level, msg: String,
  fs: List<&2, Field>) -> Maybe<&2, String>:
  match on:
    case True{}:
      Some{render(lg, t, lvl, msg, fs)}
    case False{}:
      None{}

# The line, or None when lvl is below the logger's level. A dropped line is never rendered.
def line(+lg: Logger, t: Maybe<&2, String>, +lvl: Level, msg: String,
  fs: List<&2, Field>) -> Maybe<&2, String>:
  line.if(enabled(lg, lvl), lg, t, lvl, msg, fs)

# Output
# ------

def stamp(lg: Logger, lvl: Level, msg: String, fs: List<&2, Field>) -> IO(String):
  do IO<String>:
    i : Time.Instant <- Time.now()
    return render(lg, Time.rfc3339(i), lvl, msg, fs)

def log.if(on: Bool, lg: Logger, lvl: Level, msg: String, fs: List<&2, Field>) -> IO(Unit):
  match on:
    case True{}:
      do IO<Unit>:
        s : String <- stamp(lg, lvl, msg, fs)
        IO.print_err(s)
    case False{}:
      IO.pure(Unit, Unit{})

# Writes the line to stderr, stamped with the wall clock in RFC 3339. Below the logger's level, it reads no clock.
def log(+lg: Logger, +lvl: Level, msg: String, fs: List<&2, Field>) -> IO(Unit):
  log.if(enabled(lg, lvl), lg, lvl, msg, fs)

# Write a stamped line and newline to a File; the returned handle must be kept or closed.
# Below the logger's level, returns the same handle and Done without a clock read or write.
def file.if(on: Bool, h: File, lg: Logger, lvl: Level, msg: String,
  fs: List<&2, Field>) -> IO(File & Result<&1, &1, U32 & String, Unit>):
  match on:
    case True{}:
      do IO<File & Result<&1, &1, U32 & String, Unit>>:
        s : String <- stamp(lg, lvl, msg, fs)
        File.write(h, s ++ "\n")
    case False{}:
      IO.pure(File & Result<&1, &1, U32 & String, Unit>, (h, Done{Unit{}}))

def file(h: File, +lg: Logger, +lvl: Level, msg: String,
  fs: List<&2, Field>) -> IO(File & Result<&1, &1, U32 & String, Unit>):
  file.if(enabled(lg, lvl), h, lg, lvl, msg, fs)

def debug(lg: Logger, msg: String, fs: List<&2, Field>) -> IO(Unit):
  log(lg, Debug{}, msg, fs)

def info(lg: Logger, msg: String, fs: List<&2, Field>) -> IO(Unit):
  log(lg, Info{}, msg, fs)

def warn(lg: Logger, msg: String, fs: List<&2, Field>) -> IO(Unit):
  log(lg, Warn{}, msg, fs)

def error(lg: Logger, msg: String, fs: List<&2, Field>) -> IO(Unit):
  log(lg, Error{}, msg, fs)
