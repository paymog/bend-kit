"""DNS benchmark in Python with dnspython: make_query/to_wire builds, from_wire parses (see README.md)."""
import time
import dns.exception, dns.flags, dns.message, dns.opcode, dns.rcode, dns.rdataclass, dns.rdatatype

N = 100000
TAIL = bytes([0x81, 0x80, 0, 1, 0, 1, 0, 0, 0, 0, 3, *b"www", 7, *b"example", 3, *b"com", 0, 0, 1, 0, 1,
              0xC0, 0x0C, 0, 1, 0, 1, 0, 0, 0, 0x3C, 0, 4, 93, 184, 216, 34])


# The first A/IN record's address as dotted text, like Dns.answer, or None.
def answer(qid, msg):
    try:
        m = dns.message.from_wire(msg)
    except dns.exception.DNSException:
        return None
    if m.id != qid or not m.flags & dns.flags.QR or m.opcode() != dns.opcode.QUERY or m.flags & dns.flags.TC \
            or m.rcode() != dns.rcode.NOERROR:
        return None
    for rrset in m.answer:
        if rrset.rdtype == dns.rdatatype.A and rrset.rdclass == dns.rdataclass.IN:
            return rrset[0].address
    return None


t0 = time.perf_counter()
chk = 0
for i in range(N):
    q = dns.message.make_query("www.example.com", dns.rdatatype.A, id=i & 0xFFFF)  # recursion desired, no EDNS
    chk = (chk + sum(q.to_wire())) & 0xFFFFFFFF
print(f"build\t{(time.perf_counter() - t0) * 1000:.1f}\t{chk}")

t0 = time.perf_counter()
chk = 0
for i in range(N):
    qid = i & 0xFFFF
    ip = answer(qid, qid.to_bytes(2, "big") + TAIL)
    if ip:
        chk = (chk + sum(ip.encode())) & 0xFFFFFFFF
print(f"parse\t{(time.perf_counter() - t0) * 1000:.1f}\t{chk}")
