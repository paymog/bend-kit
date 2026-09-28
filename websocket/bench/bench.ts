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
