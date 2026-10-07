import protobuf from "protobufjs";
import fs from "node:fs";

const Sample = protobuf.loadSync("bench.proto").lookupType("kit.bench.Sample");
const input = fs.readFileSync("fixture.bin");
const loops = Number(process.argv[2] ?? 100);
let checksum = 0;
const start = performance.now();
for (let i = 0; i < loops; i++) {
  const output = Sample.encode(Sample.decode(input)).finish();
  for (const byte of output) checksum += byte;
}
console.log(`${checksum}\t${(performance.now() - start).toFixed(6)}`);
