// WebSocket benchmark in JavaScript (Node): ws's Sender.frame (masked) and a server-side Receiver.
import { Receiver, Sender } from "ws";

const src = Buffer.alloc(65536);
for (let i = 0; i < 65536; i++) src[i] = (i * 7) & 255;

let last: Buffer | undefined;
const receiver = new Receiver({ isServer: true, binaryType: "nodebuffer", maxPayload: 1 << 20 });
receiver.on("message", (data: Buffer) => { last = data; });

const t0 = performance.now();
let sum = 0;
for (let k = 0; k < 256; k++) {
  const wire = Buffer.concat(Sender.frame(src, { fin: true, opcode: 2, mask: true, generateMask: (m: Buffer) => m.set([0x37, 0xfa, 0x21, 0x3d]), readOnly: true, rsv1: false }));
  // Receiver unmasks in place, so read the wire octet first.
  const w = wire[20];
  last = undefined;
  receiver.write(wire);
  if (!last) throw new Error("frame not parsed synchronously");
  sum = (sum + wire.length + w + last[65535]) >>> 0;
}
const t1 = performance.now();
console.log(`frame\t${(t1 - t0).toFixed(3)}\t${sum}`);

// stream: unmasked frames of 1000 octets, written to a client Receiver in reads of 65536 octets.
const one = Buffer.concat(Sender.frame(src.subarray(0, 1000), { fin: true, opcode: 2, mask: false, readOnly: true, rsv1: false }));
const wire = Buffer.concat(Array.from({ length: 16384 }, () => one));
let frames = 0;
let total = 0;
const client = new Receiver({ isServer: false, binaryType: "nodebuffer", maxPayload: 1 << 20 });
client.on("message", (data: Buffer) => { frames++; total = (total + data.length + data[999]) >>> 0; });
const s0 = performance.now();
for (let pos = 0; pos < wire.length; pos += 65536) client.write(wire.subarray(pos, pos + 65536));
if (frames !== 16384) throw new Error("frames not parsed synchronously");
const s1 = performance.now();
console.log(`stream\t${(s1 - s0).toFixed(3)}\t${total}`);
