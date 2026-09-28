"""SigV4 signing benchmark in Python with botocore (see README.md)."""
import datetime, time
import botocore.auth
from botocore.auth import S3SigV4Auth
from botocore.awsrequest import AWSRequest
from botocore.credentials import Credentials

N = 10000
URL = "https://examplebucket.s3.amazonaws.com/test.txt?x-id=PutObject"
BODY = b"Welcome to Amazon S3."
# add_auth reads the clock; pin it so every variant signs the same instant.
DATE = datetime.datetime(2013, 5, 24, 0, 0, 0)
botocore.auth.get_current_datetime = lambda *a, **k: DATE

auth = S3SigV4Auth(Credentials("AKIAIOSFODNN7EXAMPLE", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"), "s3", "us-east-1")

t0 = time.perf_counter()
for _ in range(N):
    req = AWSRequest(method="PUT", url=URL, data=BODY)
    auth.add_auth(req)
t1 = time.perf_counter()
print(f"sign\t{(t1 - t0) * 1000:.3f}\t{req.headers['Authorization'].rsplit('Signature=', 1)[1]}")
