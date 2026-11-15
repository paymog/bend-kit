// Journal
// =======
// Durable file effects for journal/journal.bend. Every write ends with a sync before it answers.

#ifndef JOURNAL_EFFS
#define JOURNAL_EFFS

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

// macOS fsync leaves data in the drive cache; F_FULLFSYNC flushes it where the file system can.
static int journal_sync(int fd) {
#ifdef __APPLE__
  if (fcntl(fd, F_FULLFSYNC) == 0) {
    return 0;
  }
#endif
  int r;
  do {
    r = fsync(fd);
  } while (r < 0 && errno == EINTR);
  return r;
}

static Term journal_handle_result(Env e, IoWork* w) {
  Term result = w->code ? io_fail(e, w->code, NULL) : io_done(e, term_pak(CID(Unit), 0));
  return io_tup(e, io_hand(w->hand), result);
}

#endif

#ifdef CID(open.words)

// The directory entry of a new file is durable only once its directory is synced.
static int journal_sync_dir(const char* path) {
  const char* slash = strrchr(path, '/');
  char* dir;
  if (slash == NULL) {
    dir = io_mem(strdup("."));
  } else if (slash == path) {
    dir = io_mem(strdup("/"));
  } else {
    size_t n = (size_t)(slash - path);
    dir = io_mem(malloc(n + 1));
    memcpy(dir, path, n);
    dir[n] = '\0';
  }
  int fd = open(dir, O_RDONLY | O_CLOEXEC);
  free(dir);
  if (fd < 0) {
    return -1;
  }
  int r = journal_sync(fd);
  int err = errno;
  close(fd);
  errno = err;
  return r;
}

static void journal_open_words_call(IoWork* w) {
  u64 limit = w->word;
  w->text = NULL;
  int fd = open(w->data, O_RDWR | O_CREAT | O_APPEND | O_CLOEXEC, 0644);
  if (fd < 0) {
    w->code = errno;
    return;
  }
  struct stat st;
  if (journal_sync_dir(w->data) != 0 || fstat(fd, &st) != 0) {
    w->code = errno;
    close(fd);
    return;
  }
  if ((u64)st.st_size > limit) {
    w->code = EFBIG;
    close(fd);
    return;
  }
  u64 size = (u64)st.st_size;
  char* buf = io_mem(malloc(size ? size : 1));
  u64 at = 0;
  while (at < size) {
    ssize_t n = pread(fd, buf + at, size - at, (off_t)at);
    if (n < 0 && errno == EINTR) {
      continue;
    }
    if (n <= 0) {
      w->code = n == 0 ? EIO : errno;
      free(buf);
      close(fd);
      return;
    }
    at += (u64)n;
  }
  w->hand = fd;
  w->text = buf;
  w->size = size;
  w->code = 0;
}

static Term journal_open_words_pack(Env e, IoWork* w) {
  free(w->data);
  if (w->code != 0) {
    return io_fail(e, w->code, NULL);
  }
  const unsigned char* bytes = (const unsigned char*)w->text;
  u64 n = w->size;
  u64 count = (n + 3) / 4;
  u64 depth = 0;
  Term zero = 0;
  while ((1ull << depth) < count) {
    depth++;
  }
  Term a = blk_new(e, false, depth, 0, 1, &zero);
  u64 loc = blk_loc(e.mem, a);
  for (u64 k = 0; k < count; k++) {
    u32 word = 0;
    for (u64 j = 0; j < 4 && k * 4 + j < n; j++) {
      word |= (u32)bytes[k * 4 + j] << (8 * j);
    }
    blk_write(e.mem, false, loc, (u32)k, word);
  }
  free(w->text);
  return io_done(e, io_tup(e, io_hand(w->hand), io_tup(e, (Term)n, a)));
}

Term journal_open_words_run(Env e, Term* f, IoWork* w) {
  w->data = io_cstr(e, f[0], &w->size);
  w->word = (u32)f[1];
  if (w->data == NULL || io_nul(w->data, w->size)) {
    free(w->data);
    w->data = NULL;
    return io_fail(e, EINVAL, NULL);
  }
  return io_work(w, journal_open_words_call, journal_open_words_pack);
}

static void __attribute__((constructor)) journal_open_words_use(void) {
  io_eff(CID(open.words), journal_open_words_run);
}

#endif

#ifdef CID(append.words)

static void journal_append_words_call(IoWork* w) {
  u64 at = 0;
  while (at < w->size) {
    ssize_t n = write((int)w->hand, w->data + at, w->size - at);
    if (n < 0 && errno == EINTR) {
      continue;
    }
    if (n <= 0) {
      w->code = n == 0 ? EIO : errno;
      return;
    }
    at += (u64)n;
  }
  w->code = journal_sync((int)w->hand) == 0 ? 0 : errno;
}

static Term journal_append_words_pack(Env e, IoWork* w) {
  free(w->data);
  return journal_handle_result(e, w);
}

Term journal_append_words_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  u64 n = (u64)f[1];
  Term a = f[2];
  bool bad = term_tag(a) != TAG_BUF || n > (4ull << blk_cls(a));
  w->size = bad ? 0 : n;
  w->data = io_mem(malloc(w->size ? w->size : 1));
  if (!bad) {
    u64 loc = blk_loc(e.mem, a);
    for (u64 i = 0; i < n; i++) {
      w->data[i] = (char)(blk_read(e.mem, false, loc, (u32)(i / 4)) >> (8 * (i % 4)));
    }
  }
  term_drop(e, a);
  if (bad) {
    w->code = EINVAL;
    return journal_append_words_pack(e, w);
  }
  return io_work(w, journal_append_words_call, journal_append_words_pack);
}

static void __attribute__((constructor)) journal_append_words_use(void) {
  io_eff(CID(append.words), journal_append_words_run);
}

#endif

#ifdef CID(truncate)

static void journal_truncate_call(IoWork* w) {
  int r;
  do {
    r = ftruncate((int)w->hand, (off_t)w->size);
  } while (r < 0 && errno == EINTR);
  if (r != 0) {
    w->code = errno;
    return;
  }
  w->code = journal_sync((int)w->hand) == 0 ? 0 : errno;
}

static Term journal_truncate_pack(Env e, IoWork* w) {
  return journal_handle_result(e, w);
}

Term journal_truncate_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->size = (u64)(u32)f[1];
  return io_work(w, journal_truncate_call, journal_truncate_pack);
}

static void __attribute__((constructor)) journal_truncate_use(void) {
  io_eff(CID(truncate), journal_truncate_run);
}

#endif
