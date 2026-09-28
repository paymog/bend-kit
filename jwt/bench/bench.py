"""JWT verify benchmark in Python with PyJWT: one fixed HS256 and one fixed RS256 token (see README.md)."""
import time

import jwt
from cryptography.hazmat.primitives.serialization import load_pem_public_key

N = 10_000
SECRET = b"bend-kit-jwt-bench-hs256-secret-0123456789"
PEM = b"""-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnAfhVvP/esxVFB9kHsuw
I83x79PE8FzlNOOogtlz08Pwjjf14zxEB46KHCy344mFXAFGuerTLiqRXlxd2/i8
ITk4L6hCsktjri3VBK+KkTii7dh9LbqwE083DHLL5TyUr+1Br7KmIzP76T2VaQ2c
7l+Iv8IAH8COhDf4x8raeTFDP67DyxsoHmxBdkSEKbdG9Tbl17fw44uxnqHko/5y
FmfFuzgjQ1NhQ0yymUC5uzdS+s333dXwMjxl+k/BQvcfEYc0EdaUiwrgtSBrgkqd
wpLIyVPQ59xLs5KDBEdNtRGv98IuBzwIImco3i8Ad+YB826w3NrehEinid91F7eg
yQIDAQAB
-----END PUBLIC KEY-----
"""
HS256 = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiZW5kLWtpdCIsIm5hbWUiOiJCZW5jaCBVc2VyIiwiYWRtaW4iOnRydWUsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjo0MTAyNDQ0ODAwfQ.DiAMBIAhI-CRSG3YSeQgSUn9D0fEYLlpbvvw5Ogd7GI"
RS256 = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiZW5kLWtpdCIsIm5hbWUiOiJCZW5jaCBVc2VyIiwiYWRtaW4iOnRydWUsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjo0MTAyNDQ0ODAwfQ.Hmu8V5e7RcP-BEzxtCkvda0si-bTm8UbP-yhSTvLdZq0i1gORUFRsS8_F8qJCLsjOf1cH6EsCUb4y7Sh1F4b_FMDrwtlSBAEnR1riEikfg_Yu63SDUPRnY9bdI3QJ933aPJcL1t-D3yX7_nBA2IDau8Tag26nmLNSlM3yYmPROVEtxpDm26YVwESoIaS_kCzmVqzmAdqnCkLPloDdTeWaWkeRwmYmJkXmftSLj4ZqqkgtYWhTMeq6AhXUK53NVW_4oXEhVSH0cbLlxLRDX-dFSk8mdaaT4WoRNLurQuf9kInVNudrRv-a5cxUMjifN-sJHq9RZrbvVBnhInwdEWymw"


def run(op, token, key, alg):
    s = 0
    t0 = time.perf_counter()
    for _ in range(N):
        s = (s + jwt.decode(token, key, algorithms=[alg])["iat"]) & 0xFFFFFFFF
    print(f"{op}\t{(time.perf_counter() - t0) * 1000:.3f}\t{s}")


run("hs256", HS256, SECRET, "HS256")
run("rs256", RS256, load_pem_public_key(PEM), "RS256")
