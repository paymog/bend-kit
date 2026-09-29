// IP address benchmark in Rust with std::net (see README.md). std has no CIDR type; prefixes are split by hand.
use std::net::IpAddr;
use std::time::Instant;

const ROUNDS: usize = 10000;

const ADDRS: &[&str] = &[
    "0.0.0.0",
    "127.0.0.1",
    "192.168.1.254",
    "255.255.255.255",
    "10.0.0.1",
    "::",
    "::1",
    "2001:db8::1",
    "2001:DB8:0:0:0:0:0:1",
    "2001:0db8:0000:0000:0001:0000:0000:0001",
    "fe80::1:2:3:4",
    "1:0:0:2:0:0:0:3",
    "1:2:3:4:5:6:7:8",
    "1::",
    "2001:db8:0:1:1:1:1:1",
    "::ffff:192.0.2.128",
    "::ffff:c000:280",
    "64:ff9b::192.0.2.33",
    "ff02::fb",
    "2001:db8:85a3::8a2e:370:7334",
    "",
    "1.2.3",
    "1.2.3.4.5",
    "256.1.1.1",
    "01.2.3.4",
    "1.2.3.4 ",
    "1.2.3.\u{664}",
    "1.2.3.4:80",
    "1:2:3:4:5:6:7",
    "1:2:3:4:5:6:7:8:9",
    "1:2:3:4:5:6:7::8",
    "1::2::3",
    "12345::",
    "1:2:3:4:5:6:7:",
    ":1:2:3:4:5:6:7",
    "[::1]",
    "fe80::1%en0",
    "::ffff:1.2.3",
    "1.2.3.4::1",
    "1:2:3:4:5:6:7:8::",
];

const PREFIXES: &[&str] = &[
    "10.0.0.0/8",
    "192.168.0.0/16",
    "192.168.1.0/24",
    "0.0.0.0/0",
    "203.0.113.7/32",
    "2001:db8::/32",
    "fe80::/10",
    "::/0",
    "::1/128",
    "2001:db8:85a3::/48",
    "10.0.0.0/33",
    "2001:db8::/129",
    "10.0.0.0/",
    "/8",
    "10.0.0.0/8/8",
    "10.0.0.0/-1",
];

const PROBES: &[&str] = &[
    "10.1.2.3",
    "11.0.0.1",
    "192.168.1.77",
    "192.168.2.1",
    "203.0.113.7",
    "203.0.113.8",
    "8.8.8.8",
    "2001:db8::1",
    "2001:db8:85a3::8a2e:370:7334",
    "2001:db9::1",
    "fe80::1",
    "febf:ffff::1",
    "fec0::1",
    "::1",
    "::",
];

// 1-3 decimal digits with no leading zero, at most the family's width.
fn prefix(s: &str) -> Option<(IpAddr, u32)> {
    let (a, b) = s.split_once('/')?;
    let a: IpAddr = a.parse().ok()?;
    let digits = !b.is_empty() && b.len() <= 3 && b.bytes().all(|c| c.is_ascii_digit());
    if !digits || (b.len() > 1 && b.starts_with('0')) {
        return None;
    }
    let bits: u32 = b.parse().ok()?;
    (bits <= if a.is_ipv4() { 32 } else { 128 }).then_some((a, bits))
}

fn contains(p: &(IpAddr, u32), x: &IpAddr) -> bool {
    match (p.0, x) {
        (IpAddr::V4(n), IpAddr::V4(x)) => {
            let m = u32::MAX.checked_shl(32 - p.1).unwrap_or(0);
            u32::from(n) & m == u32::from(*x) & m
        }
        (IpAddr::V6(n), IpAddr::V6(x)) => {
            let m = u128::MAX.checked_shl(128 - p.1).unwrap_or(0);
            u128::from(n) & m == u128::from(*x) & m
        }
        _ => false,
    }
}

fn addr_rounds() -> u32 {
    let mut h: u32 = 0;
    for _ in 0..ROUNDS {
        for s in ADDRS {
            match s.parse::<IpAddr>() {
                Err(_) => h = h.wrapping_mul(31).wrapping_add(1),
                Ok(a) => {
                    h = h.wrapping_mul(31).wrapping_add(2);
                    for c in a.to_string().bytes() {
                        h = h.wrapping_mul(31).wrapping_add(c as u32);
                    }
                }
            }
        }
    }
    h
}

fn cidr_rounds() -> u32 {
    let mut h: u32 = 0;
    for _ in 0..ROUNDS {
        let ps: Vec<IpAddr> = PROBES.iter().filter_map(|s| s.parse().ok()).collect();
        for s in PREFIXES {
            match prefix(s) {
                None => h = h.wrapping_mul(3),
                Some(p) => {
                    for a in &ps {
                        h = h.wrapping_mul(3).wrapping_add(if contains(&p, a) { 2 } else { 1 });
                    }
                }
            }
        }
    }
    h
}

fn main() {
    for (op, f) in [("addr", addr_rounds as fn() -> u32), ("cidr", cidr_rounds)] {
        let t0 = Instant::now();
        let h = f();
        println!("{op}\t{:.3}\t{h}", t0.elapsed().as_secs_f64() * 1000.0);
    }
}
