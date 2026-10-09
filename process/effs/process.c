// Process
// ======
// Byte-exact octet strings, like wire/effs/wire.c.

#ifndef PROCESS_BYTES
#define PROCESS_BYTES

static Term process_bytes(Env e, const char* p, u64 n) {
  Term s    = term_pak(CID_SNIL, 0);
  u64  hole = 0;
  for (u64 i = 0; i < n; i += 1) {
    u64  l = heap_alloc(e, 1);
    Term t = term_ctr(CID_SCON, l);
    e.mem[l] = (uint8_t)p[i];
    if (hole == 0) {
      s = t;
    } else {
      e.mem[hole] = io_seal(e, t, CID_SCON);
    }
    hole = l + 1;
  }
  if (hole != 0) {
    e.mem[hole] = io_seal(e, term_pak(CID_SNIL, 0), CID_SCON);
  }
  return s;
}

static char* process_octets(Env e, Term s, u64* len, bool* bad) {
  u64   cap = 64;
  u64   n   = 0;
  char* buf = io_mem(malloc(cap));
  *bad = false;
  while (term_aux(s) == CID_SCON) {
    Term fb[2];
    spare_free(e, cls_fit(2), ctr_take(e, s, 2, fb));
    if (n + 1 > cap) {
      cap *= 2;
      buf = io_mem(realloc(buf, cap));
    }
    *bad = *bad || (u64)fb[0] > 255;
    buf[n++] = (char)(fb[0] & 0xFF);
    s = fb[1];
  }
  if (term_aux(s) != CID_SNIL) {
    *bad = true;
  }
  *len = n;
  return buf;
}

#endif

#if defined(CID(run.raw)) || defined(CID(spawn)) || defined(CID(wait))
#ifndef PROCESS_EXEC
#define PROCESS_EXEC

#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern char** environ;

typedef struct {
  char*  cmd;
  char** argv;
  char** envp;
  char*  in;
  u64    in_len;
  char*  out;
  u64    out_len;
  u64    out_cap;
  char*  err;
  u64    err_len;
  u64    err_cap;
  int    status;
  int    pid;
  int    in_wr;
  int    out_rd;
  int    err_rd;
} ProcessJob;

static u32 process_exit_status(int st) {
  if (WIFEXITED(st)) {
    return (u32)WEXITSTATUS(st);
  }
  if (WIFSIGNALED(st)) {
    return 128u + (u32)WTERMSIG(st);
  }
  return 127;
}

static bool process_env_key(const char* s, u64 n, const char** val, u64* val_len) {
  u64 eq = n;
  for (u64 i = 0; i < n; i += 1) {
    if (s[i] == '=') {
      eq = i;
      break;
    }
  }
  if (eq == 0 || eq >= n) {
    return false;
  }
  *val     = s + eq + 1;
  *val_len = n - eq - 1;
  return true;
}

static char** process_env_build(Env e, Term env_list, bool* bad) {
  u64    n_ov = 0;
  u64    cap  = 8;
  char** ov   = io_mem(malloc(cap * sizeof(char*)));
  Term   xs   = env_list;
  *bad        = false;
  while (term_aux(xs) == CID_CON) {
    Term fb[2];
    spare_free(e, cls_fit(2), ctr_take(e, xs, 2, fb));
    u64   len = 0;
    char* s   = io_cstr(e, fb[0], &len);
    const char* val;
    u64         val_len;
    if (io_nul(s, len) || !process_env_key(s, len, &val, &val_len)) {
      *bad = true;
      free(s);
      break;
    }
    if (n_ov + 1 > cap) {
      cap *= 2;
      ov = io_mem(realloc(ov, cap * sizeof(char*)));
    }
    ov[n_ov++] = s;
    xs = fb[1];
  }
  if (*bad || term_aux(xs) != CID_NIL) {
    if (!*bad) {
      *bad = true;
    }
    for (u64 i = 0; i < n_ov; i += 1) {
      free(ov[i]);
    }
    free(ov);
    return NULL;
  }
  u64 n_en = 0;
  if (environ) {
    while (environ[n_en]) {
      n_en += 1;
    }
  }
  char** out = io_mem(calloc(n_en + n_ov + 1, sizeof(char*)));
  u64    at  = 0;
  for (u64 i = 0; i < n_en; i += 1) {
    const char* s = environ[i];
    u64         n = strlen(s);
    bool        skip = false;
    for (u64 j = 0; j < n_ov; j += 1) {
      const char* ov_s = ov[j];
      u64         ov_n = strlen(ov_s);
      u64         k    = 0;
      while (k < ov_n && k < n && ov_s[k] == s[k]) {
        k += 1;
      }
      if (k < ov_n && ov_s[k] == '=' && k < n && s[k] == '=') {
        skip = true;
        break;
      }
    }
    if (!skip) {
      out[at++] = io_mem(strdup(s));
    }
  }
  for (u64 j = 0; j < n_ov; j += 1) {
    out[at++] = ov[j];
  }
  free(ov);
  return out;
}

static void process_env_free(char** envp) {
  if (!envp) {
    return;
  }
  for (u64 i = 0; envp[i]; i += 1) {
    free(envp[i]);
  }
  free(envp);
}

static char** process_argv_build(Env e, char* cmd, Term args, bool* bad) {
  u64    n   = 1;
  u64    cap = 8;
  char** av  = io_mem(malloc(cap * sizeof(char*)));
  av[0]      = cmd;
  Term   xs  = args;
  *bad       = false;
  while (term_aux(xs) == CID_CON) {
    Term fb[2];
    spare_free(e, cls_fit(2), ctr_take(e, xs, 2, fb));
    u64   len = 0;
    char* s   = io_cstr(e, fb[0], &len);
    if (io_nul(s, len)) {
      *bad = true;
      free(s);
      break;
    }
    if (n + 1 > cap) {
      cap *= 2;
      av = io_mem(realloc(av, cap * sizeof(char*)));
    }
    av[n++] = s;
    xs = fb[1];
  }
  if (*bad || term_aux(xs) != CID_NIL) {
    if (!*bad) {
      *bad = true;
    }
    for (u64 i = 1; i < n; i += 1) {
      free(av[i]);
    }
    free(av);
    return NULL;
  }
  if (n + 1 > cap) {
    av = io_mem(realloc(av, (n + 1) * sizeof(char*)));
  }
  av[n] = NULL;
  return av;
}

static void process_argv_free(char** argv, char* cmd) {
  if (!argv) {
    free(cmd);
    return;
  }
  for (u64 i = 1; argv[i]; i += 1) {
    free(argv[i]);
  }
  free(argv);
  free(cmd);
}

static void process_buf_append(char** buf, u64* len, u64* cap, const char* p, u64 n) {
  if (*len + n > *cap) {
    u64 nc = *cap ? *cap : 64;
    while (*len + n > nc) {
      nc *= 2;
    }
    *buf = io_mem(realloc(*buf, nc));
    *cap = nc;
  }
  memcpy(*buf + *len, p, n);
  *len += n;
}

static void process_pipe_pair_close(int fd[2]) {
  if (fd[0] >= 0) {
    close(fd[0]);
    fd[0] = -1;
  }
  if (fd[1] >= 0) {
    close(fd[1]);
    fd[1] = -1;
  }
}

static void process_sigpipe_enter(sigset_t* old) {
  sigset_t block;
  sigemptyset(&block);
  sigaddset(&block, SIGPIPE);
  sigprocmask(SIG_BLOCK, &block, old);
}

static void process_sigpipe_leave(const sigset_t* old) {
  sigset_t pending;
  sigset_t block;
  sigemptyset(&pending);
  sigpending(&pending);
  if (sigismember(&pending, SIGPIPE)) {
    sigemptyset(&block);
    sigaddset(&block, SIGPIPE);
    int received;
    sigwait(&block, &received);
  }
  sigprocmask(SIG_SETMASK, old, NULL);
}

static bool process_stdin_write(ProcessJob* j, u64* written) {
  ssize_t n = write(j->in_wr, j->in + *written, j->in_len - *written);
  if (n < 0) {
    if (errno == EAGAIN || errno == EINTR) {
      return true;
    }
    if (errno == EPIPE) {
      close(j->in_wr);
      j->in_wr = -1;
      *written = j->in_len;
      return true;
    }
    j->status = -errno;
    return false;
  }
  *written += (u64)n;
  if (*written >= j->in_len) {
    close(j->in_wr);
    j->in_wr = -1;
  }
  return true;
}

static void process_pump_fail(ProcessJob* j, const sigset_t* sig_old) {
  j->status = -errno;
  process_sigpipe_leave(sig_old);
}

static void process_pump(ProcessJob* j) {
  if (j->in_len == 0 && j->in_wr >= 0) {
    close(j->in_wr);
    j->in_wr = -1;
  }
  sigset_t sig_old;
  process_sigpipe_enter(&sig_old);
  u64  written  = 0;
  bool out_open = true;
  bool err_open = true;
  char chunk[4096];
  for (;;) {
    struct pollfd pf[3];
    int           nf = 0;
    int           in_i = -1;
    int           out_i = -1;
    int           err_i = -1;
    if (j->in_wr >= 0 && written < j->in_len) {
      in_i = nf;
      pf[nf].fd = j->in_wr;
      pf[nf].events = POLLOUT;
      nf += 1;
    }
    if (out_open) {
      out_i = nf;
      pf[nf].fd = j->out_rd;
      pf[nf].events = POLLIN;
      nf += 1;
    }
    if (err_open) {
      err_i = nf;
      pf[nf].fd = j->err_rd;
      pf[nf].events = POLLIN;
      nf += 1;
    }
    if (nf == 0) {
      break;
    }
    if (poll(pf, nf, -1) < 0) {
      if (errno == EINTR) {
        continue;
      }
      process_pump_fail(j, &sig_old);
      return;
    }
    if (in_i >= 0 && (pf[in_i].revents & (POLLOUT | POLLERR | POLLHUP | POLLNVAL))) {
      if (!process_stdin_write(j, &written)) {
        process_sigpipe_leave(&sig_old);
        return;
      }
    }
    if (out_i >= 0 && (pf[out_i].revents & (POLLIN | POLLERR | POLLHUP | POLLNVAL))) {
      ssize_t n = read(j->out_rd, chunk, sizeof(chunk));
      if (n < 0) {
        if (errno == EINTR) {
          continue;
        }
        process_pump_fail(j, &sig_old);
        return;
      }
      if (n == 0) {
        out_open = false;
        close(j->out_rd);
        j->out_rd = -1;
      } else {
        process_buf_append(&j->out, &j->out_len, &j->out_cap, chunk, (u64)n);
      }
    }
    if (err_i >= 0 && (pf[err_i].revents & (POLLIN | POLLERR | POLLHUP | POLLNVAL))) {
      ssize_t n = read(j->err_rd, chunk, sizeof(chunk));
      if (n < 0) {
        if (errno == EINTR) {
          continue;
        }
        process_pump_fail(j, &sig_old);
        return;
      }
      if (n == 0) {
        err_open = false;
        close(j->err_rd);
        j->err_rd = -1;
      } else {
        process_buf_append(&j->err, &j->err_len, &j->err_cap, chunk, (u64)n);
      }
    }
  }
  process_sigpipe_leave(&sig_old);
}

static int process_pipe_cloexec(int pair[2]) {
  if (fcntl(pair[0], F_SETFD, FD_CLOEXEC) < 0) {
    return -1;
  }
  return fcntl(pair[1], F_SETFD, FD_CLOEXEC);
}

static int process_pipe_spawn(ProcessJob* j) {
  int in[2]  = { -1, -1 };
  int out[2] = { -1, -1 };
  int err[2] = { -1, -1 };
  if (pipe(in)) {
    return -1;
  }
  if (pipe(out)) {
    process_pipe_pair_close(in);
    return -1;
  }
  if (pipe(err)) {
    process_pipe_pair_close(in);
    process_pipe_pair_close(out);
    return -1;
  }
  if (process_pipe_cloexec(in) < 0 || process_pipe_cloexec(out) < 0
      || process_pipe_cloexec(err) < 0
      || fcntl(in[1], F_SETFL, fcntl(in[1], F_GETFL) | O_NONBLOCK) < 0) {
    int code = errno;
    process_pipe_pair_close(in);
    process_pipe_pair_close(out);
    process_pipe_pair_close(err);
    errno = code;
    return -1;
  }
  posix_spawn_file_actions_t actions;
  int rc = posix_spawn_file_actions_init(&actions);
  if (rc != 0) {
    process_pipe_pair_close(in);
    process_pipe_pair_close(out);
    process_pipe_pair_close(err);
    errno = rc;
    return -1;
  }
  rc = rc ? rc : posix_spawn_file_actions_adddup2(&actions, in[0], STDIN_FILENO);
  rc = rc ? rc : posix_spawn_file_actions_adddup2(&actions, out[1], STDOUT_FILENO);
  rc = rc ? rc : posix_spawn_file_actions_adddup2(&actions, err[1], STDERR_FILENO);
  rc = rc ? rc : posix_spawn_file_actions_addclose(&actions, in[0]);
  rc = rc ? rc : posix_spawn_file_actions_addclose(&actions, in[1]);
  rc = rc ? rc : posix_spawn_file_actions_addclose(&actions, out[0]);
  rc = rc ? rc : posix_spawn_file_actions_addclose(&actions, out[1]);
  rc = rc ? rc : posix_spawn_file_actions_addclose(&actions, err[0]);
  rc = rc ? rc : posix_spawn_file_actions_addclose(&actions, err[1]);
  posix_spawnattr_t attrs;
  bool attrs_ready = false;
  if (rc == 0) {
    rc = posix_spawnattr_init(&attrs);
    attrs_ready = rc == 0;
  }
  if (rc == 0) {
    sigset_t defaults, mask;
    sigemptyset(&defaults);
    sigaddset(&defaults, SIGPIPE);
    sigemptyset(&mask);
    rc = posix_spawnattr_setsigdefault(&attrs, &defaults);
    rc = rc ? rc : posix_spawnattr_setsigmask(&attrs, &mask);
    rc = rc ? rc : posix_spawnattr_setflags(&attrs,
      POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK);
  }
  pid_t pid = 0;
  if (rc == 0) {
    rc = posix_spawnp(&pid, j->argv[0], &actions, &attrs, j->argv, j->envp);
  }
  if (attrs_ready) {
    posix_spawnattr_destroy(&attrs);
  }
  posix_spawn_file_actions_destroy(&actions);
  close(in[0]);
  in[0] = -1;
  close(out[1]);
  out[1] = -1;
  close(err[1]);
  err[1] = -1;
  if (rc != 0) {
    process_pipe_pair_close(in);
    process_pipe_pair_close(out);
    process_pipe_pair_close(err);
    errno = rc;
    return -1;
  }
  j->in_wr  = in[1];
  j->out_rd = out[0];
  j->err_rd = err[0];
  j->pid    = (int)pid;
  return 0;
}

static void process_job_close_fds(ProcessJob* j) {
  if (j->in_wr >= 0) {
    close(j->in_wr);
    j->in_wr = -1;
  }
  if (j->out_rd >= 0) {
    close(j->out_rd);
    j->out_rd = -1;
  }
  if (j->err_rd >= 0) {
    close(j->err_rd);
    j->err_rd = -1;
  }
}

#endif
#endif

#ifdef CID(run.raw)

static void process_run_raw_call(IoWork* w) {
  ProcessJob* j = (ProcessJob*)w->data;
  w->code = 0;
  if (process_pipe_spawn(j) < 0) {
    w->code = errno;
    return;
  }
  process_pump(j);
  if (j->status < 0) {
    w->code = (u32)-j->status;
    process_job_close_fds(j);
    kill(j->pid, SIGKILL);
    waitpid(j->pid, NULL, 0);
    return;
  }
  process_job_close_fds(j);
  int st = 0;
  int result;
  do {
    result = waitpid(j->pid, &st, 0);
  } while (result < 0 && errno == EINTR);
  if (result < 0) {
    w->code = errno;
    return;
  }
  j->status = st;
}

static Term process_run_raw_pack(Env e, IoWork* w) {
  ProcessJob* j = (ProcessJob*)w->data;
  Term        r;
  if (w->code) {
    r = io_fail(e, w->code, NULL);
  } else {
    u32 code = process_exit_status(j->status);
    Term triple = io_tup(e, (Term)code,
      io_tup(e, process_bytes(e, j->out, j->out_len), process_bytes(e, j->err, j->err_len)));
    r = io_done(e, triple);
  }
  free(j->out);
  free(j->err);
  free(j->in);
  process_env_free(j->envp);
  process_argv_free(j->argv, j->cmd);
  free(j);
  w->data = NULL;
  return r;
}

Term run_raw_run(Env e, Term* f, IoWork* w) {
  u64         cmd_len = 0;
  char*       cmd     = io_cstr(e, f[0], &cmd_len);
  bool        bad     = false;
  char**      argv    = process_argv_build(e, cmd, f[1], &bad);
  char**      envp    = bad ? NULL : process_env_build(e, f[2], &bad);
  u64         in_len  = 0;
  bool        in_bad  = false;
  char*       in      = process_octets(e, f[3], &in_len, &in_bad);
  bad                 = bad || in_bad;
  ProcessJob* j       = io_mem(calloc(1, sizeof(ProcessJob)));
  j->cmd              = cmd;
  j->argv             = argv;
  j->envp             = envp;
  j->in               = in;
  j->in_len           = in_len;
  j->in_wr            = -1;
  j->out_rd           = -1;
  j->err_rd           = -1;
  w->data             = (char*)j;
  if (bad || io_nul(cmd, cmd_len) || !argv || !envp) {
    w->code = bad ? EINVAL : EILSEQ;
    return process_run_raw_pack(e, w);
  }
  return io_work(w, process_run_raw_call, process_run_raw_pack);
}

static void __attribute__((constructor)) run_raw_use(void) {
  io_eff(CID(run.raw), run_raw_run);
}

#endif

#ifdef CID(spawn)

static void process_spawn_call(IoWork* w) {
  ProcessJob* j = (ProcessJob*)w->data;
  w->code = 0;
  if (process_pipe_spawn(j) < 0) {
    w->code = errno;
  }
}

static Term process_spawn_pack(Env e, IoWork* w) {
  ProcessJob* j = (ProcessJob*)w->data;
  Term        r;
  if (w->code) {
    process_job_close_fds(j);
    r = io_fail(e, w->code, NULL);
  } else {
    Term files = io_tup(e, io_hand(j->in_wr),
      io_tup(e, io_hand(j->out_rd), io_hand(j->err_rd)));
    r = io_done(e, io_tup(e, (Term)(u32)j->pid, files));
  }
  process_env_free(j->envp);
  process_argv_free(j->argv, j->cmd);
  free(j);
  w->data = NULL;
  return r;
}

Term spawn_run(Env e, Term* f, IoWork* w) {
  u64         cmd_len = 0;
  char*       cmd     = io_cstr(e, f[0], &cmd_len);
  bool        bad     = false;
  char**      argv    = process_argv_build(e, cmd, f[1], &bad);
  char**      envp    = bad ? NULL : process_env_build(e, f[2], &bad);
  ProcessJob* j       = io_mem(calloc(1, sizeof(ProcessJob)));
  j->cmd              = cmd;
  j->argv             = argv;
  j->envp             = envp;
  j->in_wr            = -1;
  j->out_rd           = -1;
  j->err_rd           = -1;
  w->data             = (char*)j;
  if (bad || io_nul(cmd, cmd_len) || !argv || !envp) {
    w->code = bad ? EINVAL : EILSEQ;
    return process_spawn_pack(e, w);
  }
  return io_work(w, process_spawn_call, process_spawn_pack);
}

static void __attribute__((constructor)) spawn_use(void) {
  io_eff(CID(spawn), spawn_run);
}

#endif

#ifdef CID(wait)

static void process_wait_call(IoWork* w) {
  pid_t pid = (pid_t)w->hand;
  int   st  = 0;
  do {
    w->made = (intptr_t)waitpid(pid, &st, 0);
  } while (w->made < 0 && errno == EINTR);
  if (w->made < 0) {
    io_sys_end(w, -1);
  } else {
    w->word = process_exit_status(st);
    w->code = 0;
  }
}

static Term process_wait_pack(Env e, IoWork* w) {
  return w->code ? io_fail(e, w->code, NULL) : io_done(e, (Term)w->word);
}

Term wait_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)(pid_t)(u32)f[0];
  return io_work(w, process_wait_call, process_wait_pack);
}

static void __attribute__((constructor)) wait_use(void) {
  io_eff(CID(wait), wait_run);
}

#endif

#ifdef CID(read_stdin)

static void process_stdin_read_call(IoWork* w) {
  do {
    w->size = io_sys_end(w, read(STDIN_FILENO, w->data, w->word));
  } while (w->code == EINTR);
}

static Term process_stdin_read_pack(Env e, IoWork* w) {
  Term r = w->code ? io_fail(e, w->code, NULL)
    : io_done(e, process_bytes(e, w->data, w->size));
  free(w->data);
  return r;
}

Term read_stdin_run(Env e, Term* f, IoWork* w) {
  w->word = (u32)f[0] < INT32_MAX ? (u32)f[0] : INT32_MAX;
  w->data = io_mem(malloc(w->word + 1));
  return io_work(w, process_stdin_read_call, process_stdin_read_pack);
}

static void __attribute__((constructor)) read_stdin_use(void) {
  io_eff(CID(read_stdin), read_stdin_run);
}

#endif

#ifdef CID(exit.raw)

Term exit_raw_run(Env e, Term* f, IoWork* w) {
  exit((int)(u32)f[0]);
}

static void __attribute__((constructor)) exit_raw_use(void) {
  io_eff(CID(exit.raw), exit_raw_run);
}

#endif

#ifdef CID(cwd)

static void process_cwd_call(IoWork* w) {
  u64 cap = 256;
  for (;;) {
    w->data = io_mem(realloc(w->data, cap));
    if (getcwd(w->data, cap)) {
      w->size = strlen(w->data);
      w->code = 0;
      return;
    }
    if (errno != ERANGE) {
      w->code = errno;
      return;
    }
    cap *= 2;
  }
}

static Term process_cwd_pack(Env e, IoWork* w) {
  Term r = w->code ? io_fail(e, w->code, NULL)
    : io_done(e, io_str(e, w->data, w->size));
  free(w->data);
  return r;
}

Term cwd_run(Env e, Term* f, IoWork* w) {
  w->data = io_mem(malloc(256));
  return io_work(w, process_cwd_call, process_cwd_pack);
}

static void __attribute__((constructor)) cwd_use(void) {
  io_eff(CID(cwd), cwd_run);
}

#endif

#ifdef CID(chdir)

static void process_chdir_call(IoWork* w) {
  io_sys_end(w, chdir(w->data));
}

static Term process_chdir_pack(Env e, IoWork* w) {
  free(w->data);
  return w->code ? io_fail(e, w->code, NULL) : io_done(e, term_pak(CID_UNIT, 0));
}

Term chdir_run(Env e, Term* f, IoWork* w) {
  w->data = io_cstr(e, f[0], &w->size);
  if (io_nul(w->data, w->size)) {
    w->code = EILSEQ;
    return process_chdir_pack(e, w);
  }
  return io_work(w, process_chdir_call, process_chdir_pack);
}

static void __attribute__((constructor)) chdir_use(void) {
  io_eff(CID(chdir), chdir_run);
}

#endif

#ifdef CID(hostname)

static void process_hostname_call(IoWork* w) {
  w->data = io_mem(malloc((size_t)w->word + 1));
  if (gethostname(w->data, (size_t)w->word)) {
    w->code = errno;
    return;
  }
  w->data[w->word] = '\0';
  w->size = strnlen(w->data, (size_t)w->word);
  w->code = 0;
}

static Term process_hostname_pack(Env e, IoWork* w) {
  Term r = w->code ? io_fail(e, w->code, NULL)
    : io_done(e, io_str(e, w->data, w->size));
  free(w->data);
  return r;
}

Term hostname_run(Env e, Term* f, IoWork* w) {
  w->word = 256;
  return io_work(w, process_hostname_call, process_hostname_pack);
}

static void __attribute__((constructor)) hostname_use(void) {
  io_eff(CID(hostname), hostname_run);
}

#endif

#ifdef CID(pid)

Term pid_run(Env e, Term* f, IoWork* w) {
  return (Term)(u32)getpid();
}

static void __attribute__((constructor)) pid_use(void) {
  io_eff(CID(pid), pid_run);
}

#endif

#ifdef CID(signal.poll)

static volatile sig_atomic_t process_sig_pending;

static void process_sig_on(int sig) {
  process_sig_pending = sig;
}

static void process_sig_install(void) {
  static bool done;
  if (done) {
    return;
  }
  done = true;
  struct sigaction sa;
  memset(&sa, 0, sizeof(sa));
  sa.sa_handler = process_sig_on;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_RESTART;
  sigaction(SIGINT, &sa, NULL);
  sigaction(SIGTERM, &sa, NULL);
}

Term signal_poll_run(Env e, Term* f, IoWork* w) {
  process_sig_install();
  int sig = (int)process_sig_pending;
  if (sig == SIGINT || sig == SIGTERM) {
    process_sig_pending = 0;
    return (Term)(u32)sig;
  }
  return 0;
}

static void __attribute__((constructor)) signal_poll_use(void) {
  io_eff(CID(signal.poll), signal_poll_run);
}

#endif
