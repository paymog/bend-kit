import fs from 'node:fs';
const [source, destination, size, block] = process.argv.slice(2);
const cap = Number(size), chunk = Number(block);
if (chunk < 1 || chunk > 1048576) throw new Error('invalid chunk');
const src = fs.openSync(source, 'r'), dst = fs.openSync(destination, 'w');
const buffer = Buffer.alloc(chunk);
let count = 0;
try {
  while (count < cap) {
    const n = fs.readSync(src, buffer, 0, Math.min(chunk, cap - count), null);
    if (n === 0) break;
    let written = 0;
    while (written < n) {
      const step = fs.writeSync(dst, buffer, written, n - written);
      if (step === 0) throw new Error('zero-byte write');
      written += step;
    }
    count += n;
  }
  if (fs.readSync(src, buffer, 0, 1, null) !== 0) throw new Error('cap exceeded');
} finally {
  fs.closeSync(src);
  fs.closeSync(dst);
}
const output = fs.openSync(destination, 'r');
let checksum = 2166136261;
try {
  let n;
  while ((n = fs.readSync(output, buffer, 0, chunk, null)) !== 0)
    for (let i = 0; i < n; i++) checksum = Math.imul(checksum ^ buffer[i], 16777619) >>> 0;
} finally {
  fs.closeSync(output);
}
console.log(count, checksum);
