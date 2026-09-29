// OAuth2 benchmark in JavaScript (Bun and Node): node:crypto for PKCE, JSON.parse for the token response (see README.md).
import { createHash } from "node:crypto";

const N = 10_000;
let v = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";
let t0 = performance.now();
for (let i = 0; i < N; i++) v = createHash("sha256").update(v).digest("base64url");
let t1 = performance.now();
console.log(`pkce\t${(t1 - t0).toFixed(3)}\t${v}`);

type Token = { access_token: string; refresh_token: string; scope: string; expires_in: number };

const body = new TextEncoder().encode(
  `{"access_token":"${"A".repeat(1024)}","token_type":"Bearer","expires_in":3600,` +
    `"refresh_token":"tGzv3JOkF0XG5Qx2TlKWIA","scope":"openid profile email"}`,
);
const dec = new TextDecoder();
let good = 0;
let last: Token | null = null;
t0 = performance.now();
for (let i = 0; i < N; i++) {
  // The fixed input above has this shape; a real client would validate the reply.
  const t = JSON.parse(dec.decode(body)) as Token;
  if (t.access_token) (good++, (last = t));
}
t1 = performance.now();
if (!last) throw new Error("no token parsed");
console.log(`parse\t${(t1 - t0).toFixed(3)}\t${good} ${last.access_token.length} ${last.refresh_token} ${last.scope} ${last.expires_in}`);
