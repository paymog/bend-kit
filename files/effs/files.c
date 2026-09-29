// Files
// =====
// POSIX directory and path effects for files/files.bend.

#ifndef FILES_EFFS
#define FILES_EFFS

#include <dirent.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static bool files_path(Env e, Term t, char** out, u64* n) {
  *out = io_cstr(e, t, n);
  if (*out == NULL || io_nul(*out, *n)) {
    if (*out != NULL) {
      free(*out);
    }
    *out = NULL;
    return false;
  }
  return true;
}

static u32 files_kind(mode_t m) {
  if (S_ISREG(m)) {
    return 0;
  }
  if (S_ISDIR(m)) {
    return 1;
  }
  return 2;
}

static Term files_unit_done(Env e) {
  return io_done(e, term_pak(CID(Unit), 0));
}

static Term files_unit_pack(Env e, IoWork* w) {
  return w->code != 0 ? io_fail(e, w->code, NULL) : files_unit_done(e);
}

#endif

#ifdef CID(list_dir.raw)

static void files_list_grow(char** buf, u64* cap, u64 need) {
  if (need <= *cap) {
    return;
  }
  u64 ncap = *cap ? *cap : 64;
  while (ncap < need) {
    ncap *= 2;
  }
  *buf = io_mem(realloc(*buf, ncap));
  *cap = ncap;
}

static void files_list_push(char** buf, u64* len, u64* cap, const char* name) {
  if (strcmp(name, ".") == 0 || strcmp(name, "..") == 0) {
    return;
  }
  u64 n = strlen(name);
  u64 need = *len + (*len ? 1 : 0) + n;
  files_list_grow(buf, cap, need);
  if (*len != 0) {
    (*buf)[(*len)++] = '\0';
  }
  memcpy(*buf + *len, name, n);
  *len += n;
}

static void list_dir_raw_call(IoWork* w) {
  DIR* d = opendir(w->data);
  if (d == NULL) {
    io_sys_end(w, -1);
    return;
  }
  char*  buf = NULL;
  u64    len = 0;
  u64    cap = 0;
  struct dirent* de;
  errno = 0;
  while ((de = readdir(d)) != NULL) {
    files_list_push(&buf, &len, &cap, de->d_name);
  }
  int read_error = errno;
  if (read_error != 0) {
    closedir(d);
    free(buf);
    w->code = read_error;
    return;
  }
  if (closedir(d) != 0) {
    free(buf);
    io_sys_end(w, -1);
    return;
  }
  w->text = buf;
  w->size = len;
  w->code = 0;
}

static Term list_dir_raw_pack(Env e, IoWork* w) {
  free(w->data);
  if (w->code != 0) {
    free(w->text);
    return io_fail(e, w->code, NULL);
  }
  Term r = io_done(e, io_str(e, w->text, w->size));
  free(w->text);
  return r;
}

Term list_dir_raw_run(Env e, Term* f, IoWork* w) {
  if (!files_path(e, f[0], &w->data, &w->size)) {
    return io_fail(e, EINVAL, NULL);
  }
  return io_work(w, list_dir_raw_call, list_dir_raw_pack);
}

static void __attribute__((constructor)) list_dir_raw_use(void) {
  io_eff(CID(list_dir.raw), list_dir_raw_run, 0);
}

#endif

#ifdef CID(stat.raw)

static void stat_raw_call(IoWork* w) {
  struct stat st;
  io_sys_end(w, stat(w->data, &st));
  if (w->code != 0) {
    return;
  }
  w->word = files_kind(st.st_mode);
  w->made = (intptr_t)(uint32_t)st.st_size;
  w->hand = (intptr_t)(uint32_t)st.st_mtime;
}

static Term stat_raw_pack(Env e, IoWork* w) {
  free(w->data);
  if (w->code != 0) {
    return io_fail(e, w->code, NULL);
  }
  Term t = io_tup(e, (Term)w->word,
    io_tup(e, (Term)(uint32_t)w->made, (Term)(uint32_t)w->hand));
  return io_done(e, t);
}

Term stat_raw_run(Env e, Term* f, IoWork* w) {
  if (!files_path(e, f[0], &w->data, &w->size)) {
    return io_fail(e, EINVAL, NULL);
  }
  return io_work(w, stat_raw_call, stat_raw_pack);
}

static void __attribute__((constructor)) stat_raw_use(void) {
  io_eff(CID(stat.raw), stat_raw_run, 0);
}

#endif

#ifdef CID(mkdir)

static void mkdir_call(IoWork* w) {
  io_sys_end(w, mkdir(w->data, 0777));
}

static Term mkdir_pack(Env e, IoWork* w) {
  free(w->data);
  return files_unit_pack(e, w);
}

Term mkdir_run(Env e, Term* f, IoWork* w) {
  if (!files_path(e, f[0], &w->data, &w->size)) {
    return io_fail(e, EINVAL, NULL);
  }
  return io_work(w, mkdir_call, mkdir_pack);
}

static void __attribute__((constructor)) mkdir_use(void) {
  io_eff(CID(mkdir), mkdir_run, 0);
}

#endif

#ifdef CID(remove)

static void remove_call(IoWork* w) {
  io_sys_end(w, remove(w->data));
}

static Term remove_pack(Env e, IoWork* w) {
  free(w->data);
  return files_unit_pack(e, w);
}

Term remove_run(Env e, Term* f, IoWork* w) {
  if (!files_path(e, f[0], &w->data, &w->size)) {
    return io_fail(e, EINVAL, NULL);
  }
  return io_work(w, remove_call, remove_pack);
}

static void __attribute__((constructor)) remove_use(void) {
  io_eff(CID(remove), remove_run, 0);
}

#endif

#ifdef CID(rename)

static void rename_call(IoWork* w) {
  io_sys_end(w, rename(w->data, w->text));
}

static Term rename_pack(Env e, IoWork* w) {
  free(w->data);
  free(w->text);
  return files_unit_pack(e, w);
}

Term rename_run(Env e, Term* f, IoWork* w) {
  u64 to_len = 0;
  if (!files_path(e, f[0], &w->data, &w->size)
    || !files_path(e, f[1], &w->text, &to_len)) {
    free(w->data);
    free(w->text);
    w->data = NULL;
    w->text = NULL;
    return io_fail(e, EINVAL, NULL);
  }
  return io_work(w, rename_call, rename_pack);
}

static void __attribute__((constructor)) rename_use(void) {
  io_eff(CID(rename), rename_run, 0);
}

#endif

#ifdef CID(temp_dir)

static void temp_dir_call(IoWork* w) {
  const char* base = getenv("TMPDIR");
  if (base == NULL || base[0] == '\0') {
    base = "/tmp";
  }
  size_t bl = strlen(base);
  size_t need = bl + 1 + 12 + 1;
  char* tmpl = io_mem(malloc(need));
  memcpy(tmpl, base, bl);
  size_t at = bl;
  if (at == 0 || tmpl[at - 1] != '/') {
    tmpl[at++] = '/';
  }
  memcpy(tmpl + at, "bend-XXXXXX", 12);
  tmpl[at + 12] = '\0';
  if (mkdtemp(tmpl) == NULL) {
    free(tmpl);
    io_sys_end(w, -1);
    return;
  }
  w->data = tmpl;
  w->size = strlen(tmpl);
  w->code = 0;
}

static Term temp_dir_pack(Env e, IoWork* w) {
  if (w->code != 0) {
    return io_fail(e, w->code, NULL);
  }
  Term r = io_done(e, io_str(e, w->data, w->size));
  free(w->data);
  return r;
}

Term temp_dir_run(Env e, Term* f, IoWork* w) {
  (void)f;
  return io_work(w, temp_dir_call, temp_dir_pack);
}

static void __attribute__((constructor)) temp_dir_use(void) {
  io_eff(CID(temp_dir), temp_dir_run, 0);
}

#endif

#if defined(CID(read.words)) || defined(CID(write.words))

static Term files_words(Env e, const unsigned char* bytes, u64 n) {
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
  return io_tup(e, (Term)n, a);
}

static Term files_handle_result(Env e, IoWork* w, Term value) {
  free(w->data);
  Term result = w->code ? io_fail(e, w->code, NULL) : io_done(e, value);
  return io_tup(e, io_hand(w->hand), result);
}

#endif

#ifdef CID(read.words)

static void files_read_words_call(IoWork* w) {
  ssize_t n;
  do {
    n = read((int)w->hand, w->data, w->size);
  } while (n < 0 && errno == EINTR);
  if (n < 0) {
    w->code = errno;
  } else {
    w->made = n;
    w->code = 0;
  }
}

static Term files_read_words_pack(Env e, IoWork* w) {
  Term value = w->code ? 0 : files_words(e, (unsigned char*)w->data, (u64)w->made);
  return files_handle_result(e, w, value);
}

Term files_read_words_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->size = (u64)f[1] < 1048576 ? (u64)f[1] : 1048576;
  w->data = io_mem(malloc(w->size ? w->size : 1));
  return io_work(w, files_read_words_call, files_read_words_pack);
}

static void __attribute__((constructor)) files_read_words_use(void) {
  io_eff(CID(read.words), files_read_words_run, 0);
}

#endif

#ifdef CID(write.words)

static void files_write_words_call(IoWork* w) {
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
  w->code = 0;
}

static Term files_write_words_pack(Env e, IoWork* w) {
  return files_handle_result(e, w, term_pak(CID(Unit), 0));
}

Term files_write_words_run(Env e, Term* f, IoWork* w) {
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
    return files_write_words_pack(e, w);
  }
  return io_work(w, files_write_words_call, files_write_words_pack);
}

static void __attribute__((constructor)) files_write_words_use(void) {
  io_eff(CID(write.words), files_write_words_run, 0);
}

#endif
