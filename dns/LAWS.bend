import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import ./dns.bend as Dns

def bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, bytes(t)}

def msg(+xs: List<&2, U32>) -> Bytes.Bytes:
  Bytes.from_string(bytes(xs))

# The query's octets, one Char per octet.
def q(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      Some{Bytes.to_string(b)}

# RFC 1035 §4.1: header (id 0x1234, RD, QDCOUNT 1), QNAME a.bc, QTYPE A, QCLASS IN.
law query_wire:
  {q(Dns.query(4660, "a.bc")) == Some{bytes([18, 52, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 97, 2, 98, 99, 0, 0, 1, 0, 1])} : Maybe<&2, String>}

# A fully qualified name (trailing dot) is the same query.
law query_fqdn:
  {q(Dns.query(4660, "a.bc.")) == q(Dns.query(4660, "a.bc")) : Maybe<&2, String>}

# §2.3.4: labels are 1..63 octets.
law query_empty_label:
  {q(Dns.query(1, "a..bc")) == None{} : Maybe<&2, String>}

law query_long_label:
  {q(Dns.query(1, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.com")) == None{} : Maybe<&2, String>}

# Hosts are ASCII; IDNA is out of scope.
law query_non_ascii:
  {q(Dns.query(1, "é.com")) == None{} : Maybe<&2, String>}

# One A answer; its name is a §4.1.4 pointer to the question.
law answer_a:
  {Dns.answer(4660, msg([18, 52, 129, 128, 0, 1, 0, 1, 0, 0, 0, 0, 1, 97, 2, 98, 99, 0, 0, 1, 0, 1, 192, 12, 0, 1, 0, 1, 0, 0, 0, 60, 0, 4, 93, 184, 216, 34])) == Some{"93.184.216.34"} : Maybe<&2, String>}

# A CNAME before the A record is skipped.
law answer_cname_then_a:
  {Dns.answer(4660, msg([18, 52, 129, 128, 0, 1, 0, 2, 0, 0, 0, 0, 1, 97, 2, 98, 99, 0, 0, 1, 0, 1, 192, 12, 0, 5, 0, 1, 0, 0, 0, 60, 0, 2, 192, 12, 192, 12, 0, 1, 0, 1, 0, 0, 0, 60, 0, 4, 1, 2, 3, 4])) == Some{"1.2.3.4"} : Maybe<&2, String>}

# §7.3: a response whose id differs from the query's is not the answer.
law answer_wrong_id:
  {Dns.answer(4661, msg([18, 52, 129, 128, 0, 1, 0, 1, 0, 0, 0, 0, 1, 97, 2, 98, 99, 0, 0, 1, 0, 1, 192, 12, 0, 1, 0, 1, 0, 0, 0, 60, 0, 4, 93, 184, 216, 34])) == None{} : Maybe<&2, String>}

# §4.1.1: RCODE 3 (name error) has no address.
law answer_nxdomain:
  {Dns.answer(4660, msg([18, 52, 129, 131, 0, 1, 0, 0, 0, 0, 0, 0, 1, 97, 2, 98, 99, 0, 0, 1, 0, 1])) == None{} : Maybe<&2, String>}

# §4.1.1: TC set means the answer was cut; do not trust it.
law answer_truncated:
  {Dns.answer(4660, msg([18, 52, 131, 128, 0, 1, 0, 1, 0, 0, 0, 0, 1, 97, 2, 98, 99, 0, 0, 1, 0, 1, 192, 12, 0, 1, 0, 1, 0, 0, 0, 60, 0, 4, 93, 184, 216, 34])) == None{} : Maybe<&2, String>}

# QR clear: a query, not a response.
law answer_not_response:
  {Dns.answer(4660, msg([18, 52, 1, 128, 0, 1, 0, 1, 0, 0, 0, 0, 1, 97, 2, 98, 99, 0, 0, 1, 0, 1, 192, 12, 0, 1, 0, 1, 0, 0, 0, 60, 0, 4, 93, 184, 216, 34])) == None{} : Maybe<&2, String>}

# RDLENGTH beyond the message.
law answer_short_rdata:
  {Dns.answer(4660, msg([18, 52, 129, 128, 0, 1, 0, 1, 0, 0, 0, 0, 1, 97, 2, 98, 99, 0, 0, 1, 0, 1, 192, 12, 0, 1, 0, 1, 0, 0, 0, 60, 0, 4, 93, 184])) == None{} : Maybe<&2, String>}

law answer_no_a:
  {Dns.answer(4660, msg([18, 52, 129, 128, 0, 1, 0, 0, 0, 0, 0, 0, 1, 97, 2, 98, 99, 0, 0, 1, 0, 1])) == None{} : Maybe<&2, String>}

law nameserver_first:
  {Dns.nameserver("# local\nsearch lan\nnameserver 192.168.1.1\nnameserver 8.8.8.8\n") == Some{"192.168.1.1"} : Maybe<&2, String>}

law nameserver_none:
  {Dns.nameserver("search lan\n") == None{} : Maybe<&2, String>}

law nameservers_two:
  {Dns.nameservers("#\nnameserver 1.1.1.1\nnameserver 8.8.8.8\n") == ["1.1.1.1", "8.8.8.8"] : List<&2, String>}

law hosts_hit:
  {Dns.hosts("me.test", "127.0.0.1 me.test alias\n") == Some{"127.0.0.1"} : Maybe<&2, String>}

law hosts_miss:
  {Dns.hosts("no.test", "10.0.0.1 other\n") == None{} : Maybe<&2, String>}

law resolve_ipv6_literal:
  {Dns.resolve.literal("::1") == Some{"::1"} : Maybe<&2, String>}

law resolve_localhost:
  {Dns.resolve.literal.all("localhost") == ["::1", "127.0.0.1"] : List<&2, String>}

law hosts_ipv6:
  {Dns.hosts.all("v6.test", "::1 v6.test\n127.0.0.1 v6.test\n") == ["::1", "127.0.0.1"] : List<&2, String>}
