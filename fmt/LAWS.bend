import Base
import ./fmt.bend as Fmt

def f32(x: U32) -> F32:
  match x:
    case U32{w}:
      F32{w}

def short(x: U32) -> String:
  Fmt.F32.shortest(f32(x))

# A builder joins its chunks in the order they were added.
law build_order:
  {Fmt.Builder.build(Fmt.Builder.add(Fmt.Builder.add(Fmt.Builder.add(
    Fmt.Builder.new(), "ab"), ""), "cd")) == "abcd" : String}

law build_empty:
  {Fmt.Builder.build(Fmt.Builder.new()) == "" : String}

law format_holes:
  {Fmt.Fmt.format("{} of {}", ["3", "7"]) == "3 of 7" : String}

law format_escapes:
  {Fmt.Fmt.format("{{}} }}{{ {", []) == "{} }{ {" : String}

law format_missing_arg:
  {Fmt.Fmt.format("{}-{}", ["a"]) == "a-{}" : String}

law format_extra_arg:
  {Fmt.Fmt.format("{}", ["a", "b"]) == "a" : String}

law format_lone_close:
  {Fmt.Fmt.format("a}b", []) == "a}b" : String}

law pad_left_fill:
  {Fmt.Fmt.pad_left("42", 5n, '0') == "00042" : String}

law pad_left_wide:
  {Fmt.Fmt.pad_left("12345", 3n, ' ') == "12345" : String}

law pad_right_fill:
  {Fmt.Fmt.pad_right("ab", 4n, '.') == "ab.." : String}

law center_odd:
  {Fmt.Fmt.center("ab", 5n, '*') == "*ab**" : String}

law center_even:
  {Fmt.Fmt.center("ab", 6n, '-') == "--ab--" : String}

# Shortest F32 text, checked against numpy's unique Dragon4 digits.
law short_tenth:
  {Fmt.F32.shortest(0.1) == "0.1" : String}

law short_one:
  {Fmt.F32.shortest(1.0) == "1.0" : String}

law short_min_subnormal:
  {short(1) == "1e-45" : String}

law short_max_subnormal:
  {short(8388607) == "1.1754942e-38" : String}

law short_min_normal:
  {short(8388608) == "1.1754944e-38" : String}

law short_max:
  {short(2139095039) == "3.4028235e+38" : String}

law short_one_ulp:
  {short(1065353217) == "1.0000001" : String}

law short_pow2_24:
  {short(1266679808) == "16777216.0" : String}

law short_third:
  {short(1051372203) == "0.33333334" : String}

# 2070951.25 sits halfway between 2070951.2 and 2070951.3; the even digit wins.
law short_tie_even:
  {short(1241304378) == "2070951.2" : String}

law short_neg:
  {short(3223322624) == "-2.5" : String}

law short_plain_top:
  {short(1510874057) == "9999999000000000.0" : String}

law short_sci_top:
  {short(1510874058) == "1e+16" : String}

law short_plain_bottom:
  {short(953267991) == "0.0001" : String}

law short_sci_bottom:
  {short(925353388) == "1e-05" : String}

law short_zero:
  {short(0) == "0.0" : String}

law short_neg_zero:
  {short(2147483648) == "-0.0" : String}

law short_inf:
  {short(2139095040) == "inf" : String}

law short_neg_inf:
  {short(4286578688) == "-inf" : String}

law short_nan:
  {short(2143289344) == "nan" : String}
