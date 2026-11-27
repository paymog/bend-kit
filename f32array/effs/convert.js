const convertWord = new Uint32Array(1);
const convertFloat = new Float32Array(convertWord.buffer);
function convertSwap(word) {
  return ((word >>> 24) | ((word >>> 8) & 0xff00) |
    ((word << 8) & 0xff0000) | (word << 24)) >>> 0;
}
function from_bytes_raw(n, a, big) {
  if (n >= 2 ** 30) throw new RangeError("f32array: too many elements");
  let size = 1;
  while (size * 8 < n) size *= 2;
  return Array.from({ length: size }, (_, i) => {
    const cell = { $: "Cell" };
    for (let lane = 0; lane < 8; lane++) {
      const j = i * 8 + lane;
      const word = j < n ? a[j % a.length] : 0;
      convertWord[0] = big ? convertSwap(word) : word;
      cell["v" + lane] = convertFloat[0];
    }
    return cell;
  });
}
function to_bytes_raw(n, a, big) {
  let size = 1;
  if (n >= 2 ** 30) throw new RangeError("f32array: too many elements");
  while (size < n) size *= 2;
  return Array.from({ length: size }, (_, i) => {
    convertFloat[0] = i < n ? a[(i >> 3) % a.length]["v" + (i & 7)] : 0;
    const word = convertWord[0];
    return big ? convertSwap(word) : word;
  });
}
io_eff(CID(from_bytes.raw), from_bytes_raw);
io_eff(CID(to_bytes.raw), to_bytes_raw);
