# Native gzip, zstd, and brotli over Bytes.
import Base
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

# The C libraries, through packed words at the effect boundary. Call the Bytes wrappers below.
def zstd.words(max: U32, len: U32, words: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

def inflate.words(max: U32, len: U32, words: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

def inflate.raw.words(max: U32, len: U32, words: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

def gzip.words(len: U32, words: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

def brotli.words(max: U32, len: U32, words: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

def words.got(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, U32 & String, Bytes.Bytes>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(+len, buf)}:
      Done{Bytes.Bytes{len, buf}}

def words.run(~eff: U32 -> U32 -> Array<U32> -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>), max: U32, b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  Bytes.Bytes{+len, buf} = b
  do IO<Result<&1, &1, U32 & String, Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- eff(max, len, buf)
    return words.got(r)

# gzip, zlib, or raw DEFLATE data through libz, selected from the first two bytes. Every gzip member is decoded in turn, as gzip -d does.
# Each decoder fails with EFBIG when the output passes max bytes, and ENOENT without its library.
def libz.inflate(max: U32, b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  words.run(~inflate.words, max, b)

# One raw DEFLATE stream through libz. Trailing bytes, truncated input and output above max fail.
def libz.inflate.raw(max: U32, b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  words.run(~inflate.raw.words, max, b)

# One gzip member at level 6 through libz.
def libz.gzip(b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  Bytes.Bytes{+len, buf} = b
  do IO<Result<&1, &1, U32 & String, Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- gzip.words(len, buf)
    return words.got(r)

# Zstandard frames (RFC 8878) through libzstd.
def zstd(max: U32, b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  words.run(~zstd.words, max, b)

# Brotli (RFC 7932) through libbrotlidec.
def brotli(max: U32, b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  words.run(~brotli.words, max, b)

# A live native decoder. Call dec.finish even after a failed feed to release it.
type Decoder is Type:
  Decoder{id: U32}

def dec.open(kind: U32) -> IO(Result<&1, &1, U32 & String, U32>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

def dec.new.got(r: Result<&1, &1, U32 & String, U32>) -> Result<&1, &1, U32 & String, Decoder>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{+id}:
      Done{Decoder{id}}

def dec.new(+kind: U32) -> IO(Result<&1, &1, U32 & String, Decoder>):
  do IO<Result<&1, &1, U32 & String, Decoder>>:
    r : Result<&1, &1, U32 & String, U32> <- dec.open(kind)
    return dec.new.got(r)

def inflate.new() -> IO(Result<&1, &1, U32 & String, Decoder>):
  dec.new(0)

def brotli.new() -> IO(Result<&1, &1, U32 & String, Decoder>):
  dec.new(1)

def zstd.new() -> IO(Result<&1, &1, U32 & String, Decoder>):
  dec.new(2)

def dec.feed(id: U32, max: U32, len: U32, words: Array<U32>) ->
  IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

# The output of one chunk of input. max caps this call, not the total output of the stream.
def dec.push(d: Decoder, max: U32, b: Bytes.Bytes) ->
  IO(Decoder & Result<&1, &1, U32 & String, Bytes.Bytes>):
  Decoder{+id} = d
  Bytes.Bytes{+len, buf} = b
  do IO<Decoder & Result<&1, &1, U32 & String, Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- dec.feed(id, max, len, buf)
    return (Decoder{id}, words.got(r))

def dec.finish.id(id: U32) -> IO(Result<&1, &1, U32 & String, Unit>):
  import "./effs/zlib.c"
  import "./effs/zlib.js"

# Finish validates the end marker and always releases the decoder.
def dec.finish(d: Decoder) -> IO(Result<&1, &1, U32 & String, Unit>):
  Decoder{+id} = d
  dec.finish.id(id)
