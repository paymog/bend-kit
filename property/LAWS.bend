import Base
import bend-kit-random@0.1.0.0/random.bend as Rand
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import ./property.bend as Prop
import ./generate.bend as Gen
import ./shrink.bend as Shrink

def first(~T: Type, pair: T & Rand.Rng) -> T:
  (value, rng) = pair
  value

def octets(xs: List<&1, Bytes.Bytes>) -> List<&1, String>:
  List.map(~Bytes.Bytes, ~String, ~Bytes.to_string, xs)

def keep(x: U32) -> U32 & Bool:
  (x, True{})

def copy(+x: U32) -> U32 & U32:
  (x, x)

def is_zero(+x: U32) -> U32 & Bool:
  (x, U32.is_eq(x, 0))

law cap:
  {Gen.cap(4294967295) == 1024 : U32}

law random_u32:
  {first(~U32, Gen.u32(Rand.seed(42))) == 660444221 : U32}

law bounded_u32:
  {first(~U32, Gen.u32.range(5, 6, Rand.seed(42))) == 5 : U32}

law empty_string:
  {first(~String, Gen.string.of(0n, Rand.seed(42))) == "" : String}

law empty_list:
  {first(~List<&2, U32>, Gen.list.of(~U32, ~Gen.u32, 0n, Rand.seed(42))) == [] : List<&2, U32>}

law empty_bytes:
  {Bytes.to_string(first(~Bytes.Bytes, Gen.bytes.of(0, Rand.seed(42)))) == "" : String}

law zero_size:
  {first(~U32, Gen.size(0, Rand.seed(42))) == 0 : U32}

law zero_nat:
  {first(~Nat, Gen.nat(0, Rand.seed(42))) == 0n : Nat}

law shrink_one:
  {Shrink.u32(1) == [0] : List<&1, U32>}

law shrink_nat_one:
  {Shrink.nat(1n) == [0n] : List<&1, Nat>}

law shrink_list_one:
  {Shrink.list(~U32, ~Shrink.u32, [1]) == [[], [0]] : List<&1, List<&2, U32>>}

law shrink_maybe_one:
  {Shrink.maybe(~U32, ~Shrink.u32, Some{1}) == [None{}, Some{0}] : List<&1, Maybe<&2, U32>>}

law shrink_byte_one:
  {octets(Shrink.bytes(Bytes.from_string("\u{1}"))) == ["", "\0"] : List<&1, String>}

law zero_trials:
  {Prop.check(~U32, ~Gen.u32, ~(x => copy(x)), ~Shrink.u32, ~keep, 42, 0n) == None{} : Maybe<&1, Prop.Failure<U32>>}

law char_draw:
  {first(~Char, Gen.char(Rand.seed(42))) == 'I' : Char}

law fixed_string:
  {first(~String, Gen.string.of(1n, Rand.seed(42))) == "I" : String}

law fixed_byte:
  {Bytes.to_string(first(~Bytes.Bytes, Gen.bytes.of(1, Rand.seed(42)))) == "=" : String}

law bounded_string:
  {first(~String, Gen.string(0, Rand.seed(42))) == "" : String}

law bounded_bytes:
  {Bytes.to_string(first(~Bytes.Bytes, Gen.bytes(0, Rand.seed(42)))) == "" : String}

law bounded_list:
  {first(~List<&2, U32>, Gen.list(~U32, ~Gen.u32, 0, Rand.seed(42))) == [] : List<&2, U32>}

law fixed_list:
  {first(~List<&2, U32>, Gen.list.of(~U32, ~Gen.u32, 1n, Rand.seed(42))) == [660444221] : List<&2, U32>}

law maybe_draw:
  {first(~Maybe<&2, U32>, Gen.maybe(~U32, ~Gen.u32, Rand.seed(42))) == Some{3652823732} : Maybe<&2, U32>}

law map_draw:
  {first(~U32, Gen.map(~U32, ~U32, ~(x => (x + 1 : U32)), ~Gen.u32, Rand.seed(42))) == 660444222 : U32}

law bind_draw:
  {first(~U32, Gen.bind(~U32, ~U32, ~Gen.u32, ~(x => r => (x, r)), Rand.seed(42))) == 660444221 : U32}

law pair_draw:
  {first(~U32 & U32, Gen.pair(~U32, ~U32, ~Gen.u32, ~Gen.u32, Rand.seed(42))) == (660444221, 3652823732) : U32 & U32}

law shrink_char:
  {Shrink.char('b') == ['a'] : List<&1, Char>}

law shrink_string:
  {Shrink.string("b") == ["", "a"] : List<&1, String>}

law first_failure:
  {Prop.check(~U32, ~(r => (2, r)), ~(x => copy(x)), ~Shrink.u32, ~(x => is_zero(x)), 42, 1n)
    == Some{Prop.Failure{42, 0n, 1}} : Maybe<&1, Prop.Failure<U32>>}
