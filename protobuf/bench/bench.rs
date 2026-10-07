use prost::Message;

#[derive(Clone, PartialEq, Message)]
struct Sample {
    #[prost(uint32, tag = "1")]
    count: u32,
    #[prost(string, tag = "2")]
    title: String,
    #[prost(uint32, repeated, tag = "3")]
    samples: Vec<u32>,
    #[prost(double, tag = "4")]
    precise: f64,
    #[prost(bytes = "vec", tag = "5")]
    payload: Vec<u8>,
}

fn main() {
    let loops: usize = std::env::args().nth(1).unwrap_or("100".into()).parse().unwrap();
    let input = std::fs::read("fixture.bin").unwrap();
    let mut checksum: u64 = 0;
    let start = std::time::Instant::now();
    for _ in 0..loops {
        let message = Sample::decode(input.as_slice()).unwrap();
        checksum += message.encode_to_vec().iter().map(|b| *b as u64).sum::<u64>();
    }
    println!("{checksum}\t{:.6}", start.elapsed().as_secs_f64() * 1000.0);
}
