use casbin::{CoreApi, DefaultModel, Enforcer, MgmtApi};
use std::time::Instant;

const MODEL: &str = r#"
[request_definition]
r = sub, owner, act, role, resource
[policy_definition]
p = kind, val, act, eft
[policy_effect]
e = some(where (p.eft == allow)) && !some(where (p.eft == deny))
[matchers]
m = ((p.kind == "owner" && r.sub == r.owner) || (p.kind == "role" && r.role == p.val)) && (p.act == "*" || p.act == r.act)
"#;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let lg: u32 = std::env::args().nth(1).unwrap_or_else(|| "8".into()).parse()?;
    let enforcer = futures::executor::block_on(async {
        let model = DefaultModel::from_str(MODEL).await?;
        let mut e = Enforcer::new(model, ()).await?;
        for row in [["owner", "-", "DELETE", "allow"], ["role", "admin", "*", "allow"], ["role", "suspended", "*", "deny"]] {
            e.add_policy(row.into_iter().map(str::to_owned).collect()).await?;
        }
        Ok::<_, casbin::Error>(e)
    })?;
    let requests: Vec<_> = (0..64).map(|i| (
        format!("u{}", i % 7), format!("u{}", i % 5),
        ["GET", "DELETE", "PUT"][i % 3],
        if i % 11 == 0 { "admin" } else if i % 13 == 0 { "suspended" } else { "editor" },
        "doc",
    )).collect();
    let rounds = 1u32 << lg;
    let mut chk = 0u32;
    let start = Instant::now();
    for _ in 0..rounds {
        for (sub, owner, action, role, resource) in &requests {
            chk = chk.wrapping_add(u32::from(enforcer.enforce((sub.as_str(), owner.as_str(), *action, *role, *resource))?));
        }
    }
    let ms = start.elapsed().as_secs_f64() * 1000.0;
    println!("authz\t{ms:.6}\t{chk}");
    Ok(())
}