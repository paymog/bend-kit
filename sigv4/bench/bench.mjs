// SigV4 signing benchmark in JavaScript with aws-sdk-js v3's S3 signer (see README.md).
// run.py copies this next to out/js/node_modules.
// @aws-sdk/client-s3 signs through SignatureV4MultiRegion, which hands a SigV4 region to @smithy/signature-v4.
import { SignatureV4MultiRegion } from "@aws-sdk/signature-v4-multi-region";
import { Hash } from "@smithy/hash-node";
import { HttpRequest } from "@smithy/protocol-http";

const N = 10000;
const BODY = new TextEncoder().encode("Welcome to Amazon S3.");
// S3's settings, as @aws-sdk/client-s3 passes them: sign x-amz-content-sha256, encode the path once.
const signer = new SignatureV4MultiRegion({
  credentials: { accessKeyId: "AKIAIOSFODNN7EXAMPLE", secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" },
  region: "us-east-1",
  service: "s3",
  sha256: Hash.bind(null, "sha256"),
  uriEscapePath: false,
  applyChecksum: true,
});
const signingDate = new Date("2013-05-24T00:00:00Z");

let auth = "";
const t0 = performance.now();
for (let i = 0; i < N; i++) {
  const req = new HttpRequest({
    method: "PUT",
    protocol: "https:",
    hostname: "examplebucket.s3.amazonaws.com",
    path: "/test.txt",
    query: { "x-id": "PutObject" },
    headers: { host: "examplebucket.s3.amazonaws.com" },
    body: BODY,
  });
  auth = (await signer.sign(req, { signingDate })).headers.authorization;
}
const t1 = performance.now();
console.log(`sign\t${(t1 - t0).toFixed(3)}\t${auth.split("Signature=")[1]}`);
