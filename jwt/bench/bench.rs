// JWT verify benchmark in Rust with jsonwebtoken: one fixed HS256 and one fixed RS256 token (see README.md).
use jsonwebtoken::{decode, Algorithm, DecodingKey, Validation};
use serde::Deserialize;
use std::time::Instant;

const N: u32 = 10_000;
const SECRET: &[u8] = b"bend-kit-jwt-bench-hs256-secret-0123456789";
const PEM: &[u8] = b"-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnAfhVvP/esxVFB9kHsuw
I83x79PE8FzlNOOogtlz08Pwjjf14zxEB46KHCy344mFXAFGuerTLiqRXlxd2/i8
ITk4L6hCsktjri3VBK+KkTii7dh9LbqwE083DHLL5TyUr+1Br7KmIzP76T2VaQ2c
7l+Iv8IAH8COhDf4x8raeTFDP67DyxsoHmxBdkSEKbdG9Tbl17fw44uxnqHko/5y
FmfFuzgjQ1NhQ0yymUC5uzdS+s333dXwMjxl+k/BQvcfEYc0EdaUiwrgtSBrgkqd
wpLIyVPQ59xLs5KDBEdNtRGv98IuBzwIImco3i8Ad+YB826w3NrehEinid91F7eg
yQIDAQAB
-----END PUBLIC KEY-----
";
const HS256: &str = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiZW5kLWtpdCIsIm5hbWUiOiJCZW5jaCBVc2VyIiwiYWRtaW4iOnRydWUsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjo0MTAyNDQ0ODAwfQ.DiAMBIAhI-CRSG3YSeQgSUn9D0fEYLlpbvvw5Ogd7GI";
const RS256: &str = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiZW5kLWtpdCIsIm5hbWUiOiJCZW5jaCBVc2VyIiwiYWRtaW4iOnRydWUsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjo0MTAyNDQ0ODAwfQ.Hmu8V5e7RcP-BEzxtCkvda0si-bTm8UbP-yhSTvLdZq0i1gORUFRsS8_F8qJCLsjOf1cH6EsCUb4y7Sh1F4b_FMDrwtlSBAEnR1riEikfg_Yu63SDUPRnY9bdI3QJ933aPJcL1t-D3yX7_nBA2IDau8Tag26nmLNSlM3yYmPROVEtxpDm26YVwESoIaS_kCzmVqzmAdqnCkLPloDdTeWaWkeRwmYmJkXmftSLj4ZqqkgtYWhTMeq6AhXUK53NVW_4oXEhVSH0cbLlxLRDX-dFSk8mdaaT4WoRNLurQuf9kInVNudrRv-a5cxUMjifN-sJHq9RZrbvVBnhInwdEWymw";

#[derive(Deserialize)]
struct Claims {
    iat: u32,
}

fn run(op: &str, token: &str, key: &DecodingKey, alg: Algorithm) {
    let v = Validation::new(alg);
    let mut s: u32 = 0;
    let t0 = Instant::now();
    for _ in 0..N {
        s = s.wrapping_add(decode::<Claims>(token, key, &v).expect("verify").claims.iat);
    }
    println!("{op}\t{:.3}\t{s}", t0.elapsed().as_secs_f64() * 1000.0);
}

fn main() {
    run("hs256", HS256, &DecodingKey::from_secret(SECRET), Algorithm::HS256);
    run("rs256", RS256, &DecodingKey::from_rsa_pem(PEM).expect("pem"), Algorithm::RS256);
}
