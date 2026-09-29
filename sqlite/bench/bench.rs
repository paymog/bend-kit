// SQLite benchmark in Rust: N prepared inserts in one transaction, then N primary-key reads.
// std has no SQLite, so this calls libsqlite3's C API directly (no crates), like bench.c.
use std::ffi::{c_char, c_int, c_void, CStr};
use std::ptr::null_mut;
use std::time::Instant;

type Db = c_void;
type Stmt = c_void;
const OK: c_int = 0;
const ROW: c_int = 100;
const DONE: c_int = 101;

#[link(name = "sqlite3")]
extern "C" {
    fn sqlite3_libversion() -> *const c_char;
    fn sqlite3_open(path: *const c_char, db: *mut *mut Db) -> c_int;
    fn sqlite3_close(db: *mut Db) -> c_int;
    fn sqlite3_errmsg(db: *mut Db) -> *const c_char;
    fn sqlite3_exec(db: *mut Db, sql: *const c_char, cb: *mut c_void, arg: *mut c_void, err: *mut *mut c_char) -> c_int;
    fn sqlite3_prepare_v2(db: *mut Db, sql: *const c_char, n: c_int, st: *mut *mut Stmt, tail: *mut *const c_char) -> c_int;
    fn sqlite3_bind_int64(st: *mut Stmt, i: c_int, v: i64) -> c_int;
    fn sqlite3_step(st: *mut Stmt) -> c_int;
    fn sqlite3_reset(st: *mut Stmt) -> c_int;
    fn sqlite3_column_int64(st: *mut Stmt, i: c_int) -> i64;
    fn sqlite3_finalize(st: *mut Stmt) -> c_int;
}

struct Conn(*mut Db);

impl Conn {
    fn ok(&self, rc: c_int, want: c_int) {
        if rc != want {
            let msg = unsafe { CStr::from_ptr(sqlite3_errmsg(self.0)) };
            eprintln!("sqlite: {}", msg.to_string_lossy());
            std::process::exit(1);
        }
    }

    fn exec(&self, sql: &CStr) {
        self.ok(unsafe { sqlite3_exec(self.0, sql.as_ptr(), null_mut(), null_mut(), null_mut()) }, OK);
    }

    fn prepare(&self, sql: &CStr) -> *mut Stmt {
        let mut st = null_mut();
        self.ok(unsafe { sqlite3_prepare_v2(self.0, sql.as_ptr(), -1, &mut st, std::ptr::null_mut()) }, OK);
        st
    }
}

fn main() {
    let n: u32 = std::env::args().nth(1).map_or(100000, |s| s.parse().expect("row count"));
    let mut db = null_mut();
    if unsafe { sqlite3_open(c":memory:".as_ptr(), &mut db) } != OK {
        std::process::exit(1);
    }
    let c = Conn(db);
    println!("sqlite\t{}", unsafe { CStr::from_ptr(sqlite3_libversion()) }.to_string_lossy());
    c.exec(c"CREATE TABLE t(k INTEGER PRIMARY KEY, v INTEGER NOT NULL)");

    let ins = c.prepare(c"INSERT INTO t VALUES (?1, ?2)");
    let mut x: u32 = 1;
    let t0 = Instant::now();
    c.exec(c"BEGIN");
    for i in 0..n {
        unsafe {
            c.ok(sqlite3_bind_int64(ins, 1, i as i64), OK);
            c.ok(sqlite3_bind_int64(ins, 2, (x >> 1) as i64), OK);
            c.ok(sqlite3_step(ins), DONE);
            c.ok(sqlite3_reset(ins), OK);
        }
        x = x.wrapping_mul(1664525).wrapping_add(1013904223);
    }
    c.exec(c"COMMIT");
    let insert = t0.elapsed();
    let cnt = c.prepare(c"SELECT count(*) FROM t");
    let count = unsafe {
        c.ok(sqlite3_step(cnt), ROW);
        let v = sqlite3_column_int64(cnt, 0) as u32;
        sqlite3_finalize(ins);
        sqlite3_finalize(cnt);
        v
    };
    println!("insert\t{:.3}\t{}", insert.as_secs_f64() * 1e3, count);

    let sel = c.prepare(c"SELECT v FROM t WHERE k = ?1");
    let (mut h, mut k) = (0u32, 0u32);
    let t0 = Instant::now();
    for _ in 0..n {
        unsafe {
            c.ok(sqlite3_bind_int64(sel, 1, (k % n) as i64), OK);
            c.ok(sqlite3_step(sel), ROW);
            h = h.wrapping_mul(31).wrapping_add(sqlite3_column_int64(sel, 0) as u32);
            c.ok(sqlite3_reset(sel), OK);
        }
        k = k.wrapping_add(7919);
    }
    println!("select\t{:.3}\t{}", t0.elapsed().as_secs_f64() * 1e3, h);
    unsafe {
        sqlite3_finalize(sel);
        sqlite3_close(c.0);
    }
}
