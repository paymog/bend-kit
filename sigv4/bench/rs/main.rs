// SigV4 signing benchmark in Rust with aws-sigv4 (see README.md).
use aws_credential_types::Credentials;
use aws_sigv4::http_request::{sign, PayloadChecksumKind, PercentEncodingMode, SignableBody, SignableRequest, SigningSettings, UriPathNormalizationMode};
use aws_sigv4::sign::v4;
use aws_smithy_runtime_api::client::identity::Identity;
use std::time::{Duration, Instant, UNIX_EPOCH};

const N: usize = 10000;
const URL: &str = "https://examplebucket.s3.amazonaws.com/test.txt?x-id=PutObject";
const BODY: &[u8] = b"Welcome to Amazon S3.";

fn main() {
    let identity: Identity = Credentials::new("AKIAIOSFODNN7EXAMPLE", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY", None, None, "bench").into();
    // S3's settings, as aws-sdk-s3 uses: sign x-amz-content-sha256, encode the path once, no dot-segment normalization.
    let mut settings = SigningSettings::default();
    settings.payload_checksum_kind = PayloadChecksumKind::XAmzSha256;
    settings.percent_encoding_mode = PercentEncodingMode::Single;
    settings.uri_path_normalization_mode = UriPathNormalizationMode::Disabled;
    let time = UNIX_EPOCH + Duration::from_secs(1369353600); // 20130524T000000Z
    let params = v4::SigningParams::builder().identity(&identity).region("us-east-1").name("s3").time(time).settings(settings).build().unwrap().into();

    let mut sig = String::new();
    let t0 = Instant::now();
    for _ in 0..N {
        let req = SignableRequest::new("PUT", URL, std::iter::empty(), SignableBody::Bytes(BODY)).unwrap();
        sig = sign(req, &params).unwrap().into_parts().1;
    }
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("sign\t{ms:.3}\t{sig}");
}
