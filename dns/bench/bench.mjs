// DNS benchmark in JavaScript with dns-packet: encode builds, decode parses (see README.md).
// run.py copies this next to out/js/node_modules.
import packet from "dns-packet";

const N = 100000;
const TAIL = [0x81, 0x80, 0, 1, 0, 1, 0, 0, 0, 0, 3, ..."www", 7, ..."example", 3, ..."com", 0, 0, 1, 0, 1,
  0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 0x3c, 0, 4, 93, 184, 216, 34].map((c) => (typeof c === "string" ? c.charCodeAt(0) : c));

const sum = (b, acc) => {
  for (let k = 0; k < b.length; k++) acc = (acc + b[k]) >>> 0;
  return acc;
};

// The first A/IN record's address as dotted text, like Dns.answer, or null.
function answer(id, msg) {
  let m;
  try {
    m = packet.decode(msg);
  } catch {
    return null;
  }
  if (m.id !== id || m.type !== "response" || m.opcode !== "QUERY" || m.flag_tc || m.rcode !== "NOERROR") return null;
  for (const rr of m.answers) if (rr.type === "A" && rr.class === "IN") return rr.data;
  return null;
}

let t0 = performance.now();
let chk = 0;
for (let i = 0; i < N; i++) {
  const q = packet.encode({ type: "query", id: i & 0xffff, flags: packet.RECURSION_DESIRED, questions: [{ type: "A", name: "www.example.com" }] });
  chk = sum(q, chk);
}
console.log(`build\t${(performance.now() - t0).toFixed(1)}\t${chk}`);

const msg = Buffer.from([0, 0, ...TAIL]);
t0 = performance.now();
chk = 0;
for (let i = 0; i < N; i++) {
  const id = i & 0xffff;
  msg[0] = id >> 8;
  msg[1] = id & 255;
  const ip = answer(id, msg);
  if (ip) for (let k = 0; k < ip.length; k++) chk = (chk + ip.charCodeAt(k)) >>> 0;
}
console.log(`parse\t${(performance.now() - t0).toFixed(1)}\t${chk}`);
