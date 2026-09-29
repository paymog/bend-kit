// Router benchmark: match 16 requests against 8 routes with matchit, N rounds (see ../README.md).
use std::time::Instant;

const ROUNDS: usize = 10000;

const ROUTES: [(&str, &str); 8] = [
    ("GET", "/health"),
    ("GET", "/users"),
    ("POST", "/users"),
    ("GET", "/users/{id}"),
    ("PUT", "/users/{id}"),
    ("GET", "/users/{id}/posts"),
    ("GET", "/users/{id}/posts/{post}"),
    ("GET", "/orgs/{org}/repos/{repo}/issues/{num}"),
];

const REQUESTS: [(&str, &str); 16] = [
    ("GET", "/health"),
    ("GET", "/users"),
    ("POST", "/users"),
    ("GET", "/users/42"),
    ("PUT", "/users/42"),
    ("DELETE", "/users/42"),
    ("GET", "/users/7/posts"),
    ("GET", "/users/7/posts/99"),
    ("GET", "/orgs/bendlang/repos/bend/issues/1077"),
    ("GET", "/orgs/bendlang/repos/bend"),
    ("GET", "/missing"),
    ("POST", "/health"),
    ("GET", "/users/alice"),
    ("GET", "/users/alice/posts/first"),
    ("PUT", "/users/bob/posts"),
    ("GET", "/orgs/paymog/repos/bend-kit/issues/73"),
];

fn mix(h: u32, x: u32) -> u32 {
    h.wrapping_mul(31).wrapping_add(x)
}

fn main() {
    // One matchit entry per pattern, as axum does: the value lists (method, 1-based route index) in table order.
    let mut by_pattern: Vec<(&str, Vec<(&str, u32)>)> = Vec::new();
    for (i, &(method, pat)) in ROUTES.iter().enumerate() {
        match by_pattern.iter_mut().find(|(p, _)| *p == pat) {
            Some((_, methods)) => methods.push((method, i as u32 + 1)),
            None => by_pattern.push((pat, vec![(method, i as u32 + 1)])),
        }
    }
    let mut router = matchit::Router::new();
    for (pat, methods) in by_pattern {
        router.insert(pat, methods).unwrap();
    }

    let t0 = Instant::now();
    let mut h = 0u32;
    for _ in 0..ROUNDS {
        for &(method, path) in &REQUESTS {
            if let Ok(m) = router.at(path) {
                if let Some(&(_, i)) = m.value.iter().find(|(want, _)| *want == method) {
                    h = mix(h, i);
                    // Params iterate in path order, which is the route's param order.
                    for (_, v) in m.params.iter() {
                        for b in v.bytes() {
                            h = mix(h, b as u32);
                        }
                    }
                    continue;
                }
            }
            h = mix(h, 0);
        }
    }
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("route\t{ms:.1}\t{h}");
}