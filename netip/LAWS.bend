import Base
import ./netip.bend as Netip

law ipv4_value:
  {Netip.parse("192.0.2.1") == Some{Netip.V4{3221225985}} : Maybe<&2, Netip.Addr>}

law ipv4_canonical:
  {Netip.show(Netip.V4{3221225985}) == "192.0.2.1" : String}

law ipv4_invalid_octet:
  {Netip.parse("256.0.0.1") == None{} : Maybe<&2, Netip.Addr>}

law ipv4_invalid_leading_zero:
  {Netip.parse("192.0.02.1") == None{} : Maybe<&2, Netip.Addr>}

law ipv6_value:
  {Netip.parse("2001:0DB8:0:0:0:0:0:1") == Some{Netip.V6{536939960, 0, 0, 1}} : Maybe<&2, Netip.Addr>}

law ipv6_longest_run:
  {Netip.show(Netip.V6{536939960, 0, 0, 1}) == "2001:db8::1" : String}

law ipv6_leftmost_run:
  {Netip.show(Netip.V6{536939960, 0, 65536, 1}) == "2001:db8::1:0:0:1" : String}

law ipv6_loopback:
  {Netip.show(Netip.V6{0, 0, 0, 1}) == "::1" : String}

law ipv6_mapped:
  {Netip.show(Netip.V6{0, 0, 65535, 3221225985}) == "::ffff:192.0.2.1" : String}

law ipv6_mapped_parse:
  {Netip.parse("::ffff:192.0.2.1") == Some{Netip.V6{0, 0, 65535, 3221225985}} : Maybe<&2, Netip.Addr>}

law ipv6_duplicate_compression:
  {Netip.parse("1::2::3") == None{} : Maybe<&2, Netip.Addr>}

law ipv6_single_missing_group:
  {Netip.parse("1:2:3:4:5:6:7") == None{} : Maybe<&2, Netip.Addr>}

law prefix_v4:
  {Netip.prefix.parse("192.0.2.1/24") == Some{Netip.Prefix{Netip.V4{3221225985}, 24}} : Maybe<&2, Netip.Prefix>}

law prefix_v6:
  {Netip.prefix.parse("2001:db8::1/126") == Some{Netip.Prefix{Netip.V6{536939960, 0, 0, 1}, 126}} : Maybe<&2, Netip.Prefix>}

law prefix_bad_v4:
  {Netip.prefix.parse("192.0.2.1/33") == None{} : Maybe<&2, Netip.Prefix>}

law prefix_bad_v6:
  {Netip.prefix.parse("::1/129") == None{} : Maybe<&2, Netip.Prefix>}

law prefix_canonical:
  {Netip.prefix.show(Netip.Prefix{Netip.V6{536939960, 0, 0, 1}, 126}) == "2001:db8::1/126" : String}

law contains_v4_first:
  {Netip.contains(Netip.Prefix{Netip.V4{3221225985}, 24}, Netip.V4{3221225984}) == True{} : Bool}

law contains_v4_last:
  {Netip.contains(Netip.Prefix{Netip.V4{3221225985}, 24}, Netip.V4{3221226239}) == True{} : Bool}

law contains_v4_outside:
  {Netip.contains(Netip.Prefix{Netip.V4{3221225985}, 24}, Netip.V4{3221226240}) == False{} : Bool}

law contains_v6_first:
  {Netip.contains(Netip.Prefix{Netip.V6{536939960, 0, 0, 1}, 126}, Netip.V6{536939960, 0, 0, 0}) == True{} : Bool}

law contains_v6_last:
  {Netip.contains(Netip.Prefix{Netip.V6{536939960, 0, 0, 1}, 126}, Netip.V6{536939960, 0, 0, 3}) == True{} : Bool}

law contains_v6_outside:
  {Netip.contains(Netip.Prefix{Netip.V6{536939960, 0, 0, 1}, 126}, Netip.V6{536939960, 0, 0, 4}) == False{} : Bool}

law contains_wrong_family:
  {Netip.contains(Netip.Prefix{Netip.V4{0}, 0}, Netip.V6{0, 0, 0, 0}) == False{} : Bool}
