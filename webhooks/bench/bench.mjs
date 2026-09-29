// Webhook verify benchmark in JavaScript (Bun and Node) with standardwebhooks: one fixed message, 10,000 verifies (see README.md).
import { Webhook } from "standardwebhooks";

const N = 10_000;
const BODY = '{"test": 2432232314}';
// run.py signs the message at its start and passes the timestamp and signature in the environment.
const HEADERS = {
  "webhook-id": "msg_p5jXN8AQM9LWM0D4loKWxJek",
  "webhook-timestamp": process.env.WEBHOOK_TS,
  "webhook-signature": process.env.WEBHOOK_SIG,
};

const wh = new Webhook("whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw");
let n = 0;
const t0 = performance.now();
for (let i = 0; i < N; i++) {
  wh.verify(BODY, HEADERS, { jsonParse: false }); // throws on failure
  n++;
}
console.log(`verify\t${(performance.now() - t0).toFixed(3)}\t${n} ${HEADERS["webhook-id"]}`);
