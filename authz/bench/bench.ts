import { newEnforcer, newModelFromString } from "casbin";

const model = newModelFromString(`
[request_definition]
r = sub, owner, act, role, resource
[policy_definition]
p = kind, val, act, eft
[policy_effect]
e = some(where (p.eft == allow)) && !some(where (p.eft == deny))
[matchers]
m = ((p.kind == "owner" && r.sub == r.owner) || (p.kind == "role" && r.role == p.val)) && (p.act == "*" || p.act == r.act)
`);
const enforcer = await newEnforcer(model);
await enforcer.addPolicy("owner", "-", "DELETE", "allow");
await enforcer.addPolicy("role", "admin", "*", "allow");
await enforcer.addPolicy("role", "suspended", "*", "deny");
const requests = Array.from({ length: 64 }, (_, i) => [
  `u${i % 7}`, `u${i % 5}`, ["GET", "DELETE", "PUT"][i % 3],
  i % 11 === 0 ? "admin" : i % 13 === 0 ? "suspended" : "editor", "doc",
]);
const rounds = 2 ** Number(process.argv[2] ?? 8);
let chk = 0;
const t0 = performance.now();
for (let r = 0; r < rounds; r++) {
  for (const request of requests) {
    chk += Number(enforcer.enforceSync(...request));
  }
}
const elapsed = performance.now() - t0;
console.log(`authz\t${elapsed.toFixed(6)}\t${chk >>> 0}`);
