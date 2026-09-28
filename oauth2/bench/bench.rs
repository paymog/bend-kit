// OAuth2 benchmark in Rust: sha2 + base64 for PKCE, serde_json for the token response (see README.md).
use base64::{engine::general_purpose::URL_SAFE_NO_PAD, Engine};
use sha2::{Digest, Sha256};
use std::time::Instant;

fn main() {
    const N: usize = 10_000;
    let mut v = String::from("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk");
    let t0 = Instant::now();
    for _ in 0..N {
        v = URL_SAFE_NO_PAD.encode(Sha256::digest(v.as_bytes()));
    }
    println!("pkce\t{:.3}\t{}", t0.elapsed().as_secs_f64() * 1e3, v);

    let body = format!(
        "{{\"access_token\":\"{}\",\"token_type\":\"Bearer\",\"expires_in\":3600,\"refresh_token\":\"tGzv3JOkF0XG5Qx2TlKWIA\",\"scope\":\"openid profile email\"}}",
        "A".repeat(1024)
    );
    let (mut good, mut last) = (0, serde_json::Value::Null);
    let t0 = Instant::now();
    for _ in 0..N {
        let t: serde_json::Value = serde_json::from_slice(body.as_bytes()).unwrap();
        if t["access_token"].as_str().map_or(false, |s| !s.is_empty()) {
            good += 1;
            last = t;
        }
    }
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!(
        "parse\t{:.3}\t{} {} {} {} {}",
        ms,
        good,
        last["access_token"].as_str().unwrap().len(),
        last["refresh_token"].as_str().unwrap(),
        last["scope"].as_str().unwrap(),
        last["expires_in"]
    );
}
