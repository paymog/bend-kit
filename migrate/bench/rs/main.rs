// Migration benchmark in Rust with serde_json (see README.md).
use serde::Serialize;
use serde_json::{Map, Value};
use std::time::Instant;

#[derive(Serialize)]
struct V3<'a> {
    version: u32,
    id: u32,
    plan: &'a str,
    cents: u32,
    period: &'a str,
    status: &'a str,
}

fn keys(v: u64) -> Option<&'static [&'static str]> {
    match v {
        1 => Some(&["version", "id", "plan", "monthly_cents", "active"]),
        2 => Some(&["version", "id", "plan", "cents", "period", "status", "note"]),
        3 => Some(&["version", "id", "plan", "cents", "period", "status"]),
        _ => None,
    }
}

fn u32_of(r: &Map<String, Value>, k: &str) -> Option<u32> {
    r.get(k)?.as_u64().and_then(|n| u32::try_from(n).ok())
}

fn text<'a>(r: &'a Map<String, Value>, k: &str, allowed: &[&str]) -> Option<&'a str> {
    let s = r.get(k)?.as_str()?;
    (allowed.is_empty() || allowed.contains(&s)).then_some(s)
}

fn up(r: &Value) -> Option<V3<'_>> {
    let r = r.as_object()?;
    let v = r.get("version")?.as_u64()?;
    let known = keys(v)?;
    if !r.keys().all(|k| known.contains(&k.as_str())) {
        return None;
    }
    let id = u32_of(r, "id")?;
    let plan = text(r, "plan", &[])?;
    let (cents, period, status) = if v == 1 {
        let active = r.get("active")?.as_bool()?;
        (u32_of(r, "monthly_cents")?, "monthly", if active { "active" } else { "cancelled" })
    } else {
        let status = text(r, "status", &["active", "paused", "cancelled"])?;
        let period = if v == 3 || r.contains_key("period") { text(r, "period", &["monthly", "yearly"])? } else { "monthly" };
        if v == 2 && r.contains_key("note") {
            text(r, "note", &[])?;
        }
        (u32_of(r, "cents")?, period, status)
    };
    (!plan.is_empty() && cents != 0).then_some(V3 { version: 3, id, plan, cents, period, status })
}

// Checksum: h = h*31 + b, u32, then add the length.
fn chk(b: &[u8]) -> u32 {
    let h = b.iter().fold(0u32, |h, &c| h.wrapping_mul(31).wrapping_add(c as u32));
    h.wrapping_add(b.len() as u32)
}

fn main() {
    let raw = std::fs::read("out/doc.json").expect("read out/doc.json");
    let t0 = Instant::now();
    let doc: Vec<Value> = serde_json::from_slice(&raw).expect("parse");
    let out: Vec<V3> = doc.iter().map(|r| up(r).expect("invalid record")).collect();
    let bytes = serde_json::to_vec(&out).unwrap();
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("migrate\t{ms:.3}\t{}", chk(&bytes));
}
