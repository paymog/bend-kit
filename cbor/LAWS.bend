import Base
import ./cbor.bend as Cbor
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def got(m: Maybe<&1, Bytes.Bytes>) -> Bytes.Bytes:
  match m:
    case Some{b}:
      b
    case None{}:
      Bytes.new(0)

# Hex digits to Bytes (none on a typo, which then fails its law).
def hx(s: String) -> Bytes.Bytes:
  got(Bytes.from_hex(s))

def dh(s: String) -> Maybe<&1, Cbor.Val>:
  Cbor.decode(hx(s))

def hexed(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, String>:
  match m:
    case Some{b}:
      Some{Bytes.to_hex(b)}
    case None{}:
      None{}

def eh(v: Cbor.Val) -> Maybe<&2, String>:
  hexed(Cbor.encode(v))

def redec(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&1, Cbor.Val>:
  match m:
    case Some{b}:
      Cbor.decode(b)
    case None{}:
      None{}

def rt(v: Cbor.Val) -> Maybe<&1, Cbor.Val>:
  redec(Cbor.encode(v))

def u(+n: U32) -> Cbor.Val:
  Cbor.UInt{Cbor.W64{0, n}}

def ng(+n: U32) -> Cbor.Val:
  Cbor.NInt{Cbor.W64{0, n}}

def t(s: String) -> Cbor.Val:
  Cbor.TStr{Bytes.from_string(s)}

def th(s: String) -> Cbor.Val:
  Cbor.TStr{hx(s)}

def bs(s: String) -> Cbor.Val:
  Cbor.BStr{hx(s)}

def tg(+n: U32, v: Cbor.Val) -> Cbor.Val:
  Cbor.Tag{Cbor.W64{0, n}, v}

def hf(+bits: U32) -> Cbor.Val:
  Cbor.Flt{Cbor.Half{bits}}

def sg(+bits: U32) -> Cbor.Val:
  Cbor.Flt{Cbor.Single{bits}}

def db(+hi: U32, +lo: U32) -> Cbor.Val:
  Cbor.Flt{Cbor.Double{Cbor.W64{hi, lo}}}

# RFC 8949 Appendix A: each preferred encoding decodes to its value, and the value encodes back to it.
law dec_zero:
  {dh("00") == Some{u(0)} : Maybe<&1, Cbor.Val>}

law enc_zero:
  {eh(u(0)) == Some{"00"} : Maybe<&2, String>}

law dec_one:
  {dh("01") == Some{u(1)} : Maybe<&1, Cbor.Val>}

law enc_one:
  {eh(u(1)) == Some{"01"} : Maybe<&2, String>}

law dec_ten:
  {dh("0a") == Some{u(10)} : Maybe<&1, Cbor.Val>}

law enc_ten:
  {eh(u(10)) == Some{"0a"} : Maybe<&2, String>}

law dec_u23:
  {dh("17") == Some{u(23)} : Maybe<&1, Cbor.Val>}

law enc_u23:
  {eh(u(23)) == Some{"17"} : Maybe<&2, String>}

law dec_u24:
  {dh("1818") == Some{u(24)} : Maybe<&1, Cbor.Val>}

law enc_u24:
  {eh(u(24)) == Some{"1818"} : Maybe<&2, String>}

law dec_u25:
  {dh("1819") == Some{u(25)} : Maybe<&1, Cbor.Val>}

law enc_u25:
  {eh(u(25)) == Some{"1819"} : Maybe<&2, String>}

law dec_u100:
  {dh("1864") == Some{u(100)} : Maybe<&1, Cbor.Val>}

law enc_u100:
  {eh(u(100)) == Some{"1864"} : Maybe<&2, String>}

law dec_u1000:
  {dh("1903e8") == Some{u(1000)} : Maybe<&1, Cbor.Val>}

law enc_u1000:
  {eh(u(1000)) == Some{"1903e8"} : Maybe<&2, String>}

law dec_u1000000:
  {dh("1a000f4240") == Some{u(1000000)} : Maybe<&1, Cbor.Val>}

law enc_u1000000:
  {eh(u(1000000)) == Some{"1a000f4240"} : Maybe<&2, String>}

law dec_u1e12:
  {dh("1b000000e8d4a51000") == Some{Cbor.UInt{Cbor.W64{232, 3567587328}}} : Maybe<&1, Cbor.Val>}

law enc_u1e12:
  {eh(Cbor.UInt{Cbor.W64{232, 3567587328}}) == Some{"1b000000e8d4a51000"} : Maybe<&2, String>}

law dec_u64_max:
  {dh("1bffffffffffffffff") == Some{Cbor.UInt{Cbor.W64{4294967295, 4294967295}}} : Maybe<&1, Cbor.Val>}

law enc_u64_max:
  {eh(Cbor.UInt{Cbor.W64{4294967295, 4294967295}}) == Some{"1bffffffffffffffff"} : Maybe<&2, String>}

law dec_bignum:
  {dh("c249010000000000000000") == Some{tg(2, bs("010000000000000000"))} : Maybe<&1, Cbor.Val>}

law enc_bignum:
  {eh(tg(2, bs("010000000000000000"))) == Some{"c249010000000000000000"} : Maybe<&2, String>}

law dec_nint_max:
  {dh("3bffffffffffffffff") == Some{Cbor.NInt{Cbor.W64{4294967295, 4294967295}}} : Maybe<&1, Cbor.Val>}

law enc_nint_max:
  {eh(Cbor.NInt{Cbor.W64{4294967295, 4294967295}}) == Some{"3bffffffffffffffff"} : Maybe<&2, String>}

law dec_negbignum:
  {dh("c349010000000000000000") == Some{tg(3, bs("010000000000000000"))} : Maybe<&1, Cbor.Val>}

law enc_negbignum:
  {eh(tg(3, bs("010000000000000000"))) == Some{"c349010000000000000000"} : Maybe<&2, String>}

law dec_negative_one:
  {dh("20") == Some{ng(0)} : Maybe<&1, Cbor.Val>}

law enc_negative_one:
  {eh(ng(0)) == Some{"20"} : Maybe<&2, String>}

law dec_neg10:
  {dh("29") == Some{ng(9)} : Maybe<&1, Cbor.Val>}

law enc_neg10:
  {eh(ng(9)) == Some{"29"} : Maybe<&2, String>}

law dec_neg100:
  {dh("3863") == Some{ng(99)} : Maybe<&1, Cbor.Val>}

law enc_neg100:
  {eh(ng(99)) == Some{"3863"} : Maybe<&2, String>}

law dec_neg1000:
  {dh("3903e7") == Some{ng(999)} : Maybe<&1, Cbor.Val>}

law enc_neg1000:
  {eh(ng(999)) == Some{"3903e7"} : Maybe<&2, String>}

law dec_half_zero:
  {dh("f90000") == Some{hf(0)} : Maybe<&1, Cbor.Val>}

law enc_half_zero:
  {eh(hf(0)) == Some{"f90000"} : Maybe<&2, String>}

law dec_half_negzero:
  {dh("f98000") == Some{hf(32768)} : Maybe<&1, Cbor.Val>}

law enc_half_negzero:
  {eh(hf(32768)) == Some{"f98000"} : Maybe<&2, String>}

law dec_half:
  {dh("f93c00") == Some{hf(15360)} : Maybe<&1, Cbor.Val>}

law enc_half:
  {eh(hf(15360)) == Some{"f93c00"} : Maybe<&2, String>}

law dec_double_1_1:
  {dh("fb3ff199999999999a") == Some{db(1072798105, 2576980378)} : Maybe<&1, Cbor.Val>}

law enc_double_1_1:
  {eh(db(1072798105, 2576980378)) == Some{"fb3ff199999999999a"} : Maybe<&2, String>}

law dec_half_1_5:
  {dh("f93e00") == Some{hf(15872)} : Maybe<&1, Cbor.Val>}

law enc_half_1_5:
  {eh(hf(15872)) == Some{"f93e00"} : Maybe<&2, String>}

law dec_half_65504:
  {dh("f97bff") == Some{hf(31743)} : Maybe<&1, Cbor.Val>}

law enc_half_65504:
  {eh(hf(31743)) == Some{"f97bff"} : Maybe<&2, String>}

law dec_single_100000:
  {dh("fa47c35000") == Some{sg(1203982336)} : Maybe<&1, Cbor.Val>}

law enc_single_100000:
  {eh(sg(1203982336)) == Some{"fa47c35000"} : Maybe<&2, String>}

law dec_single_max:
  {dh("fa7f7fffff") == Some{sg(2139095039)} : Maybe<&1, Cbor.Val>}

law enc_single_max:
  {eh(sg(2139095039)) == Some{"fa7f7fffff"} : Maybe<&2, String>}

law dec_double_1e300:
  {dh("fb7e37e43c8800759c") == Some{db(2117592124, 2281731484)} : Maybe<&1, Cbor.Val>}

law enc_double_1e300:
  {eh(db(2117592124, 2281731484)) == Some{"fb7e37e43c8800759c"} : Maybe<&2, String>}

law dec_half_subnormal:
  {dh("f90001") == Some{hf(1)} : Maybe<&1, Cbor.Val>}

law enc_half_subnormal:
  {eh(hf(1)) == Some{"f90001"} : Maybe<&2, String>}

law dec_half_min_normal:
  {dh("f90400") == Some{hf(1024)} : Maybe<&1, Cbor.Val>}

law enc_half_min_normal:
  {eh(hf(1024)) == Some{"f90400"} : Maybe<&2, String>}

law dec_half_neg4:
  {dh("f9c400") == Some{hf(50176)} : Maybe<&1, Cbor.Val>}

law enc_half_neg4:
  {eh(hf(50176)) == Some{"f9c400"} : Maybe<&2, String>}

law dec_double_neg4_1:
  {dh("fbc010666666666666") == Some{db(3222300262, 1717986918)} : Maybe<&1, Cbor.Val>}

law enc_double_neg4_1:
  {eh(db(3222300262, 1717986918)) == Some{"fbc010666666666666"} : Maybe<&2, String>}

law dec_half_inf:
  {dh("f97c00") == Some{hf(31744)} : Maybe<&1, Cbor.Val>}

law enc_half_inf:
  {eh(hf(31744)) == Some{"f97c00"} : Maybe<&2, String>}

law dec_half_nan:
  {dh("f97e00") == Some{hf(32256)} : Maybe<&1, Cbor.Val>}

law enc_half_nan:
  {eh(hf(32256)) == Some{"f97e00"} : Maybe<&2, String>}

law dec_half_neginf:
  {dh("f9fc00") == Some{hf(64512)} : Maybe<&1, Cbor.Val>}

law enc_half_neginf:
  {eh(hf(64512)) == Some{"f9fc00"} : Maybe<&2, String>}

law dec_single_inf:
  {dh("fa7f800000") == Some{sg(2139095040)} : Maybe<&1, Cbor.Val>}

law enc_single_inf:
  {eh(sg(2139095040)) == Some{"fa7f800000"} : Maybe<&2, String>}

law dec_single_nan:
  {dh("fa7fc00000") == Some{sg(2143289344)} : Maybe<&1, Cbor.Val>}

law enc_single_nan:
  {eh(sg(2143289344)) == Some{"fa7fc00000"} : Maybe<&2, String>}

law dec_single_neginf:
  {dh("faff800000") == Some{sg(4286578688)} : Maybe<&1, Cbor.Val>}

law enc_single_neginf:
  {eh(sg(4286578688)) == Some{"faff800000"} : Maybe<&2, String>}

law dec_double_inf:
  {dh("fb7ff0000000000000") == Some{db(2146435072, 0)} : Maybe<&1, Cbor.Val>}

law enc_double_inf:
  {eh(db(2146435072, 0)) == Some{"fb7ff0000000000000"} : Maybe<&2, String>}

law dec_double_nan:
  {dh("fb7ff8000000000000") == Some{db(2146959360, 0)} : Maybe<&1, Cbor.Val>}

law enc_double_nan:
  {eh(db(2146959360, 0)) == Some{"fb7ff8000000000000"} : Maybe<&2, String>}

law dec_double_neginf:
  {dh("fbfff0000000000000") == Some{db(4293918720, 0)} : Maybe<&1, Cbor.Val>}

law enc_double_neginf:
  {eh(db(4293918720, 0)) == Some{"fbfff0000000000000"} : Maybe<&2, String>}

law dec_single:
  {dh("fa3f800000") == Some{sg(1065353216)} : Maybe<&1, Cbor.Val>}

law enc_single:
  {eh(sg(1065353216)) == Some{"fa3f800000"} : Maybe<&2, String>}

law dec_double:
  {dh("fb3ff0000000000000") == Some{db(1072693248, 0)} : Maybe<&1, Cbor.Val>}

law enc_double:
  {eh(db(1072693248, 0)) == Some{"fb3ff0000000000000"} : Maybe<&2, String>}

law dec_false:
  {dh("f4") == Some{Cbor.Sim{Cbor.SFalse{}}} : Maybe<&1, Cbor.Val>}

law enc_false:
  {eh(Cbor.Sim{Cbor.SFalse{}}) == Some{"f4"} : Maybe<&2, String>}

law dec_true:
  {dh("f5") == Some{Cbor.Sim{Cbor.STrue{}}} : Maybe<&1, Cbor.Val>}

law enc_true:
  {eh(Cbor.Sim{Cbor.STrue{}}) == Some{"f5"} : Maybe<&2, String>}

law dec_null:
  {dh("f6") == Some{Cbor.Sim{Cbor.SNull{}}} : Maybe<&1, Cbor.Val>}

law enc_null:
  {eh(Cbor.Sim{Cbor.SNull{}}) == Some{"f6"} : Maybe<&2, String>}

law dec_undefined:
  {dh("f7") == Some{Cbor.Sim{Cbor.SUndefined{}}} : Maybe<&1, Cbor.Val>}

law enc_undefined:
  {eh(Cbor.Sim{Cbor.SUndefined{}}) == Some{"f7"} : Maybe<&2, String>}

law dec_simple16:
  {dh("f0") == Some{Cbor.Sim{Cbor.Other{16}}} : Maybe<&1, Cbor.Val>}

law enc_simple16:
  {eh(Cbor.Sim{Cbor.Other{16}}) == Some{"f0"} : Maybe<&2, String>}

law dec_simple32:
  {dh("f820") == Some{Cbor.Sim{Cbor.Other{32}}} : Maybe<&1, Cbor.Val>}

law enc_simple32:
  {eh(Cbor.Sim{Cbor.Other{32}}) == Some{"f820"} : Maybe<&2, String>}

law dec_simple255:
  {dh("f8ff") == Some{Cbor.Sim{Cbor.Other{255}}} : Maybe<&1, Cbor.Val>}

law enc_simple255:
  {eh(Cbor.Sim{Cbor.Other{255}}) == Some{"f8ff"} : Maybe<&2, String>}

law dec_tag_datetime:
  {dh("c074323031332d30332d32315432303a30343a30305a") == Some{tg(0, t("2013-03-21T20:04:00Z"))} : Maybe<&1, Cbor.Val>}

law enc_tag_datetime:
  {eh(tg(0, t("2013-03-21T20:04:00Z"))) == Some{"c074323031332d30332d32315432303a30343a30305a"} : Maybe<&2, String>}

law dec_tag_epoch:
  {dh("c11a514b67b0") == Some{tg(1, u(1363896240))} : Maybe<&1, Cbor.Val>}

law enc_tag_epoch:
  {eh(tg(1, u(1363896240))) == Some{"c11a514b67b0"} : Maybe<&2, String>}

law dec_tag_epoch_float:
  {dh("c1fb41d452d9ec200000") == Some{tg(1, db(1104433881, 3961520128))} : Maybe<&1, Cbor.Val>}

law enc_tag_epoch_float:
  {eh(tg(1, db(1104433881, 3961520128))) == Some{"c1fb41d452d9ec200000"} : Maybe<&2, String>}

law dec_tag_base16:
  {dh("d74401020304") == Some{tg(23, bs("01020304"))} : Maybe<&1, Cbor.Val>}

law enc_tag_base16:
  {eh(tg(23, bs("01020304"))) == Some{"d74401020304"} : Maybe<&2, String>}

law dec_tag_cbor:
  {dh("d818456449455446") == Some{tg(24, bs("6449455446"))} : Maybe<&1, Cbor.Val>}

law enc_tag_cbor:
  {eh(tg(24, bs("6449455446"))) == Some{"d818456449455446"} : Maybe<&2, String>}

law dec_tag_uri:
  {dh("d82076687474703a2f2f7777772e6578616d706c652e636f6d") == Some{tg(32, t("http://www.example.com"))} : Maybe<&1, Cbor.Val>}

law enc_tag_uri:
  {eh(tg(32, t("http://www.example.com"))) == Some{"d82076687474703a2f2f7777772e6578616d706c652e636f6d"} : Maybe<&2, String>}

law dec_bytes_empty:
  {dh("40") == Some{bs("")} : Maybe<&1, Cbor.Val>}

law enc_bytes_empty:
  {eh(bs("")) == Some{"40"} : Maybe<&2, String>}

law dec_bytes:
  {dh("4401020304") == Some{bs("01020304")} : Maybe<&1, Cbor.Val>}

law enc_bytes:
  {eh(bs("01020304")) == Some{"4401020304"} : Maybe<&2, String>}

law dec_text_empty:
  {dh("60") == Some{t("")} : Maybe<&1, Cbor.Val>}

law enc_text_empty:
  {eh(t("")) == Some{"60"} : Maybe<&2, String>}

law dec_text:
  {dh("6161") == Some{t("a")} : Maybe<&1, Cbor.Val>}

law enc_text:
  {eh(t("a")) == Some{"6161"} : Maybe<&2, String>}

law dec_text_ietf:
  {dh("6449455446") == Some{t("IETF")} : Maybe<&1, Cbor.Val>}

law enc_text_ietf:
  {eh(t("IETF")) == Some{"6449455446"} : Maybe<&2, String>}

law dec_text_escapes:
  {dh("62225c") == Some{th("225c")} : Maybe<&1, Cbor.Val>}

law enc_text_escapes:
  {eh(th("225c")) == Some{"62225c"} : Maybe<&2, String>}

law dec_text_u_umlaut:
  {dh("62c3bc") == Some{th("c3bc")} : Maybe<&1, Cbor.Val>}

law enc_text_u_umlaut:
  {eh(th("c3bc")) == Some{"62c3bc"} : Maybe<&2, String>}

law dec_text_water:
  {dh("63e6b0b4") == Some{th("e6b0b4")} : Maybe<&1, Cbor.Val>}

law enc_text_water:
  {eh(th("e6b0b4")) == Some{"63e6b0b4"} : Maybe<&2, String>}

law dec_text_four_byte:
  {dh("64f0908591") == Some{th("f0908591")} : Maybe<&1, Cbor.Val>}

law enc_text_four_byte:
  {eh(th("f0908591")) == Some{"64f0908591"} : Maybe<&2, String>}

law dec_array_empty:
  {dh("80") == Some{Cbor.Arr{[]}} : Maybe<&1, Cbor.Val>}

law enc_array_empty:
  {eh(Cbor.Arr{[]}) == Some{"80"} : Maybe<&2, String>}

law dec_array:
  {dh("83010203") == Some{Cbor.Arr{[u(1), u(2), u(3)]}} : Maybe<&1, Cbor.Val>}

law enc_array:
  {eh(Cbor.Arr{[u(1), u(2), u(3)]}) == Some{"83010203"} : Maybe<&2, String>}

law dec_array_nested:
  {dh("8301820203820405") == Some{Cbor.Arr{[u(1), Cbor.Arr{[u(2), u(3)]}, Cbor.Arr{[u(4), u(5)]}]}} : Maybe<&1, Cbor.Val>}

law enc_array_nested:
  {eh(Cbor.Arr{[u(1), Cbor.Arr{[u(2), u(3)]}, Cbor.Arr{[u(4), u(5)]}]}) == Some{"8301820203820405"} : Maybe<&2, String>}

law dec_array_25:
  {dh("98190102030405060708090a0b0c0d0e0f101112131415161718181819") == Some{Cbor.Arr{[u(1), u(2), u(3), u(4), u(5), u(6), u(7), u(8), u(9), u(10), u(11), u(12), u(13), u(14), u(15), u(16), u(17), u(18), u(19), u(20), u(21), u(22), u(23), u(24), u(25)]}} : Maybe<&1, Cbor.Val>}

law enc_array_25:
  {eh(Cbor.Arr{[u(1), u(2), u(3), u(4), u(5), u(6), u(7), u(8), u(9), u(10), u(11), u(12), u(13), u(14), u(15), u(16), u(17), u(18), u(19), u(20), u(21), u(22), u(23), u(24), u(25)]}) == Some{"98190102030405060708090a0b0c0d0e0f101112131415161718181819"} : Maybe<&2, String>}

law dec_map_empty:
  {dh("a0") == Some{Cbor.Obj{[]}} : Maybe<&1, Cbor.Val>}

law enc_map_empty:
  {eh(Cbor.Obj{[]}) == Some{"a0"} : Maybe<&2, String>}

law dec_map:
  {dh("a201020304") == Some{Cbor.Obj{[(u(1), u(2)), (u(3), u(4))]}} : Maybe<&1, Cbor.Val>}

law enc_map:
  {eh(Cbor.Obj{[(u(1), u(2)), (u(3), u(4))]}) == Some{"a201020304"} : Maybe<&2, String>}

law dec_map_text:
  {dh("a26161016162820203") == Some{Cbor.Obj{[(t("a"), u(1)), (t("b"), Cbor.Arr{[u(2), u(3)]})]}} : Maybe<&1, Cbor.Val>}

law enc_map_text:
  {eh(Cbor.Obj{[(t("a"), u(1)), (t("b"), Cbor.Arr{[u(2), u(3)]})]}) == Some{"a26161016162820203"} : Maybe<&2, String>}

law dec_array_map:
  {dh("826161a161626163") == Some{Cbor.Arr{[t("a"), Cbor.Obj{[(t("b"), t("c"))]}]}} : Maybe<&1, Cbor.Val>}

law enc_array_map:
  {eh(Cbor.Arr{[t("a"), Cbor.Obj{[(t("b"), t("c"))]}]}) == Some{"826161a161626163"} : Maybe<&2, String>}

law dec_map_five:
  {dh("a56161614161626142616361436164614461656145") == Some{Cbor.Obj{[(t("a"), t("A")), (t("b"), t("B")), (t("c"), t("C")), (t("d"), t("D")), (t("e"), t("E"))]}} : Maybe<&1, Cbor.Val>}

law enc_map_five:
  {eh(Cbor.Obj{[(t("a"), t("A")), (t("b"), t("B")), (t("c"), t("C")), (t("d"), t("D")), (t("e"), t("E"))]}) == Some{"a56161614161626142616361436164614461656145"} : Maybe<&2, String>}

law dec_u255:
  {dh("18ff") == Some{u(255)} : Maybe<&1, Cbor.Val>}

law enc_u255:
  {eh(u(255)) == Some{"18ff"} : Maybe<&2, String>}

law dec_u256:
  {dh("190100") == Some{u(256)} : Maybe<&1, Cbor.Val>}

law enc_u256:
  {eh(u(256)) == Some{"190100"} : Maybe<&2, String>}

law dec_u65535:
  {dh("19ffff") == Some{u(65535)} : Maybe<&1, Cbor.Val>}

law enc_u65535:
  {eh(u(65535)) == Some{"19ffff"} : Maybe<&2, String>}

law dec_u65536:
  {dh("1a00010000") == Some{u(65536)} : Maybe<&1, Cbor.Val>}

law enc_u65536:
  {eh(u(65536)) == Some{"1a00010000"} : Maybe<&2, String>}

law dec_u32_boundary:
  {dh("1affffffff") == Some{u(4294967295)} : Maybe<&1, Cbor.Val>}

law enc_u32_boundary:
  {eh(u(4294967295)) == Some{"1affffffff"} : Maybe<&2, String>}

law dec_u2_32:
  {dh("1b0000000100000000") == Some{Cbor.UInt{Cbor.W64{1, 0}}} : Maybe<&1, Cbor.Val>}

law enc_u2_32:
  {eh(Cbor.UInt{Cbor.W64{1, 0}}) == Some{"1b0000000100000000"} : Maybe<&2, String>}

law dec_neg24:
  {dh("3818") == Some{ng(24)} : Maybe<&1, Cbor.Val>}

law enc_neg24:
  {eh(ng(24)) == Some{"3818"} : Maybe<&2, String>}

law dec_tag_u64:
  {dh("dbffffffffffffffff00") == Some{Cbor.Tag{Cbor.W64{4294967295, 4294967295}, u(0)}} : Maybe<&1, Cbor.Val>}

law enc_tag_u64:
  {eh(Cbor.Tag{Cbor.W64{4294967295, 4294967295}, u(0)}) == Some{"dbffffffffffffffff00"} : Maybe<&2, String>}

law dec_array_24:
  {dh("9818000000000000000000000000000000000000000000000000") == Some{Cbor.Arr{[u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0)]}} : Maybe<&1, Cbor.Val>}

law enc_array_24:
  {eh(Cbor.Arr{[u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0), u(0)]}) == Some{"9818000000000000000000000000000000000000000000000000"} : Maybe<&2, String>}

law dec_bytes_24:
  {dh("5818616161616161616161616161616161616161616161616161") == Some{bs("616161616161616161616161616161616161616161616161")} : Maybe<&1, Cbor.Val>}

law enc_bytes_24:
  {eh(bs("616161616161616161616161616161616161616161616161")) == Some{"5818616161616161616161616161616161616161616161616161"} : Maybe<&2, String>}

law dec_map_one:
  {dh("a10102") == Some{Cbor.Obj{[(u(1), u(2))]}} : Maybe<&1, Cbor.Val>}

law enc_map_one:
  {eh(Cbor.Obj{[(u(1), u(2))]}) == Some{"a10102"} : Maybe<&2, String>}

# Appendix A indefinite forms decode to definite values; encode writes the definite form.
law dec_indef_bytes:
  {dh("5f42010243030405ff") == Some{bs("0102030405")} : Maybe<&1, Cbor.Val>}

law enc_indef_bytes:
  {eh(bs("0102030405")) == Some{"450102030405"} : Maybe<&2, String>}

law dec_indef_text:
  {dh("7f657374726561646d696e67ff") == Some{t("streaming")} : Maybe<&1, Cbor.Val>}

law enc_indef_text:
  {eh(t("streaming")) == Some{"6973747265616d696e67"} : Maybe<&2, String>}

law dec_indef_bytes_none:
  {dh("5fff") == Some{bs("")} : Maybe<&1, Cbor.Val>}

law enc_indef_bytes_none:
  {eh(bs("")) == Some{"40"} : Maybe<&2, String>}

law dec_indef_text_none:
  {dh("7fff") == Some{t("")} : Maybe<&1, Cbor.Val>}

law enc_indef_text_none:
  {eh(t("")) == Some{"60"} : Maybe<&2, String>}

law dec_indef_text_utf8:
  {dh("7f62c3bc63e6b0b4ff") == Some{th("c3bce6b0b4")} : Maybe<&1, Cbor.Val>}

law enc_indef_text_utf8:
  {eh(th("c3bce6b0b4")) == Some{"65c3bce6b0b4"} : Maybe<&2, String>}

law dec_indef_array_empty:
  {dh("9fff") == Some{Cbor.Arr{[]}} : Maybe<&1, Cbor.Val>}

law enc_indef_array_empty:
  {eh(Cbor.Arr{[]}) == Some{"80"} : Maybe<&2, String>}

law dec_indef_array_nested:
  {dh("9f018202039f0405ffff") == Some{Cbor.Arr{[u(1), Cbor.Arr{[u(2), u(3)]}, Cbor.Arr{[u(4), u(5)]}]}} : Maybe<&1, Cbor.Val>}

law enc_indef_array_nested:
  {eh(Cbor.Arr{[u(1), Cbor.Arr{[u(2), u(3)]}, Cbor.Arr{[u(4), u(5)]}]}) == Some{"8301820203820405"} : Maybe<&2, String>}

law dec_indef_array_outer:
  {dh("9f01820203820405ff") == Some{Cbor.Arr{[u(1), Cbor.Arr{[u(2), u(3)]}, Cbor.Arr{[u(4), u(5)]}]}} : Maybe<&1, Cbor.Val>}

law enc_indef_array_outer:
  {eh(Cbor.Arr{[u(1), Cbor.Arr{[u(2), u(3)]}, Cbor.Arr{[u(4), u(5)]}]}) == Some{"8301820203820405"} : Maybe<&2, String>}

law dec_indef_array_last:
  {dh("83018202039f0405ff") == Some{Cbor.Arr{[u(1), Cbor.Arr{[u(2), u(3)]}, Cbor.Arr{[u(4), u(5)]}]}} : Maybe<&1, Cbor.Val>}

law enc_indef_array_last:
  {eh(Cbor.Arr{[u(1), Cbor.Arr{[u(2), u(3)]}, Cbor.Arr{[u(4), u(5)]}]}) == Some{"8301820203820405"} : Maybe<&2, String>}

law dec_indef_array_middle:
  {dh("83019f0203ff820405") == Some{Cbor.Arr{[u(1), Cbor.Arr{[u(2), u(3)]}, Cbor.Arr{[u(4), u(5)]}]}} : Maybe<&1, Cbor.Val>}

law enc_indef_array_middle:
  {eh(Cbor.Arr{[u(1), Cbor.Arr{[u(2), u(3)]}, Cbor.Arr{[u(4), u(5)]}]}) == Some{"8301820203820405"} : Maybe<&2, String>}

law dec_indef_array_25:
  {dh("9f0102030405060708090a0b0c0d0e0f101112131415161718181819ff") == Some{Cbor.Arr{[u(1), u(2), u(3), u(4), u(5), u(6), u(7), u(8), u(9), u(10), u(11), u(12), u(13), u(14), u(15), u(16), u(17), u(18), u(19), u(20), u(21), u(22), u(23), u(24), u(25)]}} : Maybe<&1, Cbor.Val>}

law enc_indef_array_25:
  {eh(Cbor.Arr{[u(1), u(2), u(3), u(4), u(5), u(6), u(7), u(8), u(9), u(10), u(11), u(12), u(13), u(14), u(15), u(16), u(17), u(18), u(19), u(20), u(21), u(22), u(23), u(24), u(25)]}) == Some{"98190102030405060708090a0b0c0d0e0f101112131415161718181819"} : Maybe<&2, String>}

law dec_indef_map:
  {dh("bf61610161629f0203ffff") == Some{Cbor.Obj{[(t("a"), u(1)), (t("b"), Cbor.Arr{[u(2), u(3)]})]}} : Maybe<&1, Cbor.Val>}

law enc_indef_map:
  {eh(Cbor.Obj{[(t("a"), u(1)), (t("b"), Cbor.Arr{[u(2), u(3)]})]}) == Some{"a26161016162820203"} : Maybe<&2, String>}

law dec_indef_map_inner:
  {dh("826161bf61626163ff") == Some{Cbor.Arr{[t("a"), Cbor.Obj{[(t("b"), t("c"))]}]}} : Maybe<&1, Cbor.Val>}

law enc_indef_map_inner:
  {eh(Cbor.Arr{[t("a"), Cbor.Obj{[(t("b"), t("c"))]}]}) == Some{"826161a161626163"} : Maybe<&2, String>}

law dec_indef_map_fun:
  {dh("bf6346756ef563416d7421ff") == Some{Cbor.Obj{[(t("Fun"), Cbor.Sim{Cbor.STrue{}}), (t("Amt"), ng(1))]}} : Maybe<&1, Cbor.Val>}

law enc_indef_map_fun:
  {eh(Cbor.Obj{[(t("Fun"), Cbor.Sim{Cbor.STrue{}}), (t("Amt"), ng(1))]}) == Some{"a26346756ef563416d7421"} : Maybe<&2, String>}

law dec_indef_map_empty:
  {dh("bfff") == Some{Cbor.Obj{[]}} : Maybe<&1, Cbor.Val>}

law enc_indef_map_empty:
  {eh(Cbor.Obj{[]}) == Some{"a0"} : Maybe<&2, String>}

law dec_indef_tagged:
  {dh("c29f5f4101ff9fffff") == Some{tg(2, Cbor.Arr{[bs("01"), Cbor.Arr{[]}]})} : Maybe<&1, Cbor.Val>}

law enc_indef_tagged:
  {eh(tg(2, Cbor.Arr{[bs("01"), Cbor.Arr{[]}]})) == Some{"c282410180"} : Maybe<&2, String>}

law dec_indef_deep:
  {dh("9f9f9f9fffffffff") == Some{Cbor.Arr{[Cbor.Arr{[Cbor.Arr{[Cbor.Arr{[]}]}]}]}} : Maybe<&1, Cbor.Val>}

law enc_indef_deep:
  {eh(Cbor.Arr{[Cbor.Arr{[Cbor.Arr{[Cbor.Arr{[]}]}]}]}) == Some{"81818180"} : Maybe<&2, String>}

law dec_indef_map_indef_key:
  {dh("bf5f4161ff9fffff") == Some{Cbor.Obj{[(bs("61"), Cbor.Arr{[]})]}} : Maybe<&1, Cbor.Val>}

law enc_indef_map_indef_key:
  {eh(Cbor.Obj{[(bs("61"), Cbor.Arr{[]})]}) == Some{"a1416180"} : Maybe<&2, String>}

# Well-formed but not preferred heads decode; encode picks the shortest head.
law dec_u23_long:
  {dh("1817") == Some{u(23)} : Maybe<&1, Cbor.Val>}

law dec_u0_wide:
  {dh("1b0000000000000000") == Some{u(0)} : Maybe<&1, Cbor.Val>}

law dec_len_long:
  {dh("580161") == Some{bs("61")} : Maybe<&1, Cbor.Val>}

law dec_simple19:
  {dh("f3") == Some{Cbor.Sim{Cbor.Other{19}}} : Maybe<&1, Cbor.Val>}

law dec_array_long:
  {dh("9a0000000101") == Some{Cbor.Arr{[u(1)]}} : Maybe<&1, Cbor.Val>}

# Malformed input (RFC 8949 §3, Appendix F) and invalid UTF-8 text decode to None.
law dec_empty:
  {dh("") == None{} : Maybe<&1, Cbor.Val>}

law dec_trailing:
  {dh("0000") == None{} : Maybe<&1, Cbor.Val>}

law dec_trailing_array:
  {dh("8000") == None{} : Maybe<&1, Cbor.Val>}

law dec_truncated:
  {dh("18") == None{} : Maybe<&1, Cbor.Val>}

law dec_truncated16:
  {dh("1901") == None{} : Maybe<&1, Cbor.Val>}

law dec_truncated32:
  {dh("1a000000") == None{} : Maybe<&1, Cbor.Val>}

law dec_truncated64:
  {dh("1b00000000000000") == None{} : Maybe<&1, Cbor.Val>}

law dec_truncated_half:
  {dh("f93c") == None{} : Maybe<&1, Cbor.Val>}

law dec_truncated_double:
  {dh("fb3ff00000000000") == None{} : Maybe<&1, Cbor.Val>}

law dec_truncated_bytes:
  {dh("41") == None{} : Maybe<&1, Cbor.Val>}

law dec_truncated_text:
  {dh("6261") == None{} : Maybe<&1, Cbor.Val>}

law dec_truncated_array:
  {dh("81") == None{} : Maybe<&1, Cbor.Val>}

law dec_truncated_map:
  {dh("a101") == None{} : Maybe<&1, Cbor.Val>}

law dec_truncated_tag:
  {dh("c0") == None{} : Maybe<&1, Cbor.Val>}

law dec_unclosed_array:
  {dh("9f01") == None{} : Maybe<&1, Cbor.Val>}

law dec_unclosed_map:
  {dh("bf0102") == None{} : Maybe<&1, Cbor.Val>}

law dec_unclosed_bytes:
  {dh("5f4101") == None{} : Maybe<&1, Cbor.Val>}

law dec_odd_indef_map:
  {dh("bf01ff") == None{} : Maybe<&1, Cbor.Val>}

law dec_break_top:
  {dh("ff") == None{} : Maybe<&1, Cbor.Val>}

law dec_break_definite_array:
  {dh("81ff") == None{} : Maybe<&1, Cbor.Val>}

law dec_break_definite_map:
  {dh("a1ff") == None{} : Maybe<&1, Cbor.Val>}

law dec_break_map_value:
  {dh("a101ff") == None{} : Maybe<&1, Cbor.Val>}

law dec_break_tag:
  {dh("c0ff") == None{} : Maybe<&1, Cbor.Val>}

law dec_chunk_not_string:
  {dh("5f00ff") == None{} : Maybe<&1, Cbor.Val>}

law dec_chunk_indefinite:
  {dh("5f5f4101ffff") == None{} : Maybe<&1, Cbor.Val>}

law dec_chunk_wrong_major:
  {dh("5f6161ff") == None{} : Maybe<&1, Cbor.Val>}

law dec_chunk_text_in_bytes:
  {dh("7f4161ff") == None{} : Maybe<&1, Cbor.Val>}

law dec_chunk_split_utf8:
  {dh("7f61c361bcff") == None{} : Maybe<&1, Cbor.Val>}

law dec_chunk_bad_utf8:
  {dh("7f61ffff") == None{} : Maybe<&1, Cbor.Val>}

law dec_utf8_bad_byte:
  {dh("61ff") == None{} : Maybe<&1, Cbor.Val>}

law dec_utf8_truncated:
  {dh("62c328") == None{} : Maybe<&1, Cbor.Val>}

law dec_utf8_surrogate:
  {dh("63eda080") == None{} : Maybe<&1, Cbor.Val>}

law dec_utf8_overlong:
  {dh("62c080") == None{} : Maybe<&1, Cbor.Val>}

law dec_utf8_past_max:
  {dh("64f4908080") == None{} : Maybe<&1, Cbor.Val>}

law dec_utf8_lone_cont:
  {dh("6180") == None{} : Maybe<&1, Cbor.Val>}

law dec_reserved:
  {dh("1c") == None{} : Maybe<&1, Cbor.Val>}

law dec_reserved29:
  {dh("1d") == None{} : Maybe<&1, Cbor.Val>}

law dec_reserved30:
  {dh("1e") == None{} : Maybe<&1, Cbor.Val>}

law dec_reserved_nint:
  {dh("3c") == None{} : Maybe<&1, Cbor.Val>}

law dec_reserved_bytes:
  {dh("5c") == None{} : Maybe<&1, Cbor.Val>}

law dec_reserved_text:
  {dh("7c") == None{} : Maybe<&1, Cbor.Val>}

law dec_reserved_array:
  {dh("9c") == None{} : Maybe<&1, Cbor.Val>}

law dec_reserved_map:
  {dh("bc") == None{} : Maybe<&1, Cbor.Val>}

law dec_reserved_tag:
  {dh("dc") == None{} : Maybe<&1, Cbor.Val>}

law dec_reserved_simple:
  {dh("fc") == None{} : Maybe<&1, Cbor.Val>}

law dec_indef_uint:
  {dh("1f") == None{} : Maybe<&1, Cbor.Val>}

law dec_indef_nint:
  {dh("3f") == None{} : Maybe<&1, Cbor.Val>}

law dec_indef_tag:
  {dh("df") == None{} : Maybe<&1, Cbor.Val>}

law dec_simple_reserved:
  {dh("f800") == None{} : Maybe<&1, Cbor.Val>}

law dec_simple_reserved31:
  {dh("f81f") == None{} : Maybe<&1, Cbor.Val>}

law dec_simple_reserved24:
  {dh("f818") == None{} : Maybe<&1, Cbor.Val>}

law dec_count_past_u32:
  {dh("9bffffffffffffffff") == None{} : Maybe<&1, Cbor.Val>}

law dec_count_past_input:
  {dh("9a0000000201") == None{} : Maybe<&1, Cbor.Val>}

law dec_map_count_past_input:
  {dh("ba0000000201") == None{} : Maybe<&1, Cbor.Val>}

law dec_bytes_past_u32:
  {dh("5b000000010000000061") == None{} : Maybe<&1, Cbor.Val>}

# Values with no CBOR form are rejected, not written as something else.
law enc_simple_reserved:
  {eh(Cbor.Sim{Cbor.Other{24}}) == None{} : Maybe<&2, String>}

law enc_simple_named:
  {eh(Cbor.Sim{Cbor.Other{20}}) == None{} : Maybe<&2, String>}

law enc_simple_wide:
  {eh(Cbor.Sim{Cbor.Other{256}}) == None{} : Maybe<&2, String>}

law enc_half_wide:
  {eh(hf(65536)) == None{} : Maybe<&2, String>}

law enc_text_bad_utf8:
  {eh(th("ff")) == None{} : Maybe<&2, String>}

law enc_text_bad_nested:
  {eh(Cbor.Arr{[u(1), Cbor.Obj{[(th("c328"), u(2))]}]}) == None{} : Maybe<&2, String>}

# Decode inverts encode.
law roundtrip_zero:
  {rt(u(0)) == Some{u(0)} : Maybe<&1, Cbor.Val>}

law roundtrip_nested:
  {rt(Cbor.Arr{[u(1), Cbor.NInt{Cbor.W64{4294967295, 4294967295}}, Cbor.Obj{[(th("c3bc"), tg(24, bs("00ff"))), (Cbor.UInt{Cbor.W64{256, 0}}, Cbor.Arr{[Cbor.Sim{Cbor.SNull{}}, Cbor.Sim{Cbor.Other{255}}, Cbor.Sim{Cbor.Other{0}}]})]}, db(1072798105, 2576980378), hf(32256), sg(2139095040), t(""), bs("")]}) == Some{Cbor.Arr{[u(1), Cbor.NInt{Cbor.W64{4294967295, 4294967295}}, Cbor.Obj{[(th("c3bc"), tg(24, bs("00ff"))), (Cbor.UInt{Cbor.W64{256, 0}}, Cbor.Arr{[Cbor.Sim{Cbor.SNull{}}, Cbor.Sim{Cbor.Other{255}}, Cbor.Sim{Cbor.Other{0}}]})]}, db(1072798105, 2576980378), hf(32256), sg(2139095040), t(""), bs("")]}} : Maybe<&1, Cbor.Val>}

law roundtrip_simple:
  {rt(Cbor.Sim{Cbor.Other{19}}) == Some{Cbor.Sim{Cbor.Other{19}}} : Maybe<&1, Cbor.Val>}

law roundtrip_deep:
  {rt(Cbor.Arr{[Cbor.Arr{[Cbor.Arr{[Cbor.Obj{[(Cbor.Arr{[]}, Cbor.Obj{[]})]}]}]}]}) == Some{Cbor.Arr{[Cbor.Arr{[Cbor.Arr{[Cbor.Obj{[(Cbor.Arr{[]}, Cbor.Obj{[]})]}]}]}]}} : Maybe<&1, Cbor.Val>}

law roundtrip_tag_nest:
  {rt(tg(0, tg(4294967295, Cbor.Sim{Cbor.SUndefined{}}))) == Some{tg(0, tg(4294967295, Cbor.Sim{Cbor.SUndefined{}}))} : Maybe<&1, Cbor.Val>}
