// Standalone regression check for sqlite/effs/sqlite.c's open-addressing handle registry.
// Verifies floor-bounded sequential churn, concurrent growth and shrink, and
// backward-shift deletion across collision and wraparound clusters.

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

typedef uint32_t u32;

static void* io_mem(void* p) {
  if (p == NULL) {
    fprintf(stderr, "sqlite registry check: out of memory\n");
    abort();
  }
  return p;
}

#include "sqlite_reg.h"

static void check_sequential_churn_floor(void) {
  SqliteReg r = { 0 };
  u32 prev = 0;
  for (u32 i = 0; i < 5000; i += 1) {
    void* p = (void*)(uintptr_t)(i + 1);
    u32 id = sqlite_put(&r, p);
    assert(id == prev + 1);
    assert(r.len == 1);
    assert(r.cap == 64);
    assert(sqlite_get(&r, id) == p);
    if (prev != 0) {
      assert(sqlite_get(&r, prev) == NULL);
    }
    sqlite_del(&r, id);
    assert(r.len == 0);
    assert(r.cap == 64);
    assert(sqlite_get(&r, id) == NULL);
    prev = id;
  }
  assert(r.next == 5001);
  free(r.at);
}

static void check_grow_and_shrink(void) {
  SqliteReg r = { 0 };
  enum { N = 2000 };
  u32 ids[N];
  for (u32 i = 0; i < N; i += 1) {
    ids[i] = sqlite_put(&r, (void*)(uintptr_t)(0x10000u + i));
    assert(ids[i] == i + 1);
  }
  assert(r.len == N);
  assert(r.cap >= 4096);
  for (u32 i = 0; i < N; i += 1) {
    assert(sqlite_get(&r, ids[i]) == (void*)(uintptr_t)(0x10000u + i));
  }
  // Delete all but 5 handles; hysteresis shrink must return capacity to the 64 floor.
  for (u32 i = 0; i < N - 5; i += 1) {
    sqlite_del(&r, ids[i]);
    assert(sqlite_get(&r, ids[i]) == NULL);
  }
  assert(r.len == 5);
  assert(r.cap == 64);
  for (u32 i = N - 5; i < N; i += 1) {
    assert(sqlite_get(&r, ids[i]) == (void*)(uintptr_t)(0x10000u + i));
  }
  for (u32 i = N - 5; i < N; i += 1) {
    sqlite_del(&r, ids[i]);
  }
  assert(r.len == 0);
  assert(r.cap == 64);
  free(r.at);
}

// Allocate the next monotonic id whose hash lands on target_slot in a cap=64 table.
static u32 put_at_slot(SqliteReg* r, u32 target_slot, void* p) {
  for (;;) {
    u32 id = sqlite_put(r, p);
    assert(id != 0);
    assert(r->cap == 64);
    if (sqlite_hash(id, 63) == target_slot) {
      return id;
    }
    sqlite_del(r, id);
  }
}

static void check_wraparound_collision_delete(void) {
  SqliteReg r = { 0 };
  // Build a contiguous wraparound cluster spanning slots 62, 63, 0, 1, 2:
  //   slot 62 <- a1 (home 62)
  //   slot 63 <- b1 (home 63)
  //   slot 0  <- a2 (home 62, displaced across wraparound)
  //   slot 1  <- c1 (home 0, displaced by a2)
  //   slot 2  <- b2 (home 63, displaced across wraparound)
  void* pa1 = (void*)(uintptr_t)0xA1;
  void* pb1 = (void*)(uintptr_t)0xB1;
  void* pa2 = (void*)(uintptr_t)0xA2;
  void* pc1 = (void*)(uintptr_t)0xC1;
  void* pb2 = (void*)(uintptr_t)0xB2;

  u32 a1 = put_at_slot(&r, 62, pa1);
  u32 b1 = put_at_slot(&r, 63, pb1);
  u32 a2 = put_at_slot(&r, 62, pa2);
  u32 c1 = put_at_slot(&r, 0,  pc1);
  u32 b2 = put_at_slot(&r, 63, pb2);

  assert(r.cap == 64);
  assert(r.len == 5);
  assert(r.at[62].id == a1);
  assert(r.at[63].id == b1);
  assert(r.at[0].id  == a2);
  assert(r.at[1].id  == c1);
  assert(r.at[2].id  == b2);

  // Delete b1 at slot 63: a2 (home 62) must shift back to 63, c1 (home 0) must
  // stay >= 0 (shifting to 0), and b2 (home 63) must remain reachable.
  sqlite_del(&r, b1);
  assert(r.len == 4);
  assert(sqlite_get(&r, b1) == NULL);
  assert(sqlite_get(&r, a1) == pa1);
  assert(sqlite_get(&r, a2) == pa2);
  assert(sqlite_get(&r, c1) == pc1);
  assert(sqlite_get(&r, b2) == pb2);

  // Delete a1 at slot 62 (head of the wraparound cluster).
  sqlite_del(&r, a1);
  assert(r.len == 3);
  assert(sqlite_get(&r, a1) == NULL);
  assert(sqlite_get(&r, a2) == pa2);
  assert(sqlite_get(&r, c1) == pc1);
  assert(sqlite_get(&r, b2) == pb2);

  // Delete remaining entries in reverse order.
  sqlite_del(&r, b2);
  assert(sqlite_get(&r, b2) == NULL);
  assert(sqlite_get(&r, a2) == pa2);
  assert(sqlite_get(&r, c1) == pc1);

  sqlite_del(&r, c1);
  assert(sqlite_get(&r, c1) == NULL);
  assert(sqlite_get(&r, a2) == pa2);

  sqlite_del(&r, a2);
  assert(r.len == 0);
  assert(sqlite_get(&r, a2) == NULL);

  // Verify no stray non-zero slots remain.
  for (u32 i = 0; i < r.cap; i += 1) {
    assert(r.at[i].id == 0);
  }
  free(r.at);
}

int main(void) {
  (void)sqlite_dbs;
  (void)sqlite_sts;
  check_sequential_churn_floor();
  check_grow_and_shrink();
  check_wraparound_collision_delete();
  printf("sqlite registry check ok\n");
  return 0;
}
