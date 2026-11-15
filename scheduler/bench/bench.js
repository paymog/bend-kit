const start = performance.now();
const queue = Array.from({length: 1024}, (_, id) => ({deadline: (id * 37) % 64, id}));
queue.sort((a, b) => a.deadline - b.deadline || a.id - b.id);
let checksum = 0;
for (const {id} of queue) checksum = (Math.imul(checksum, 31) + id) >>> 0;
console.log(`${(performance.now() - start).toFixed(6)}\t${checksum}`);
