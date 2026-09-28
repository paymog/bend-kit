// WebSocket benchmark in Rust: tungstenite masks and formats, then FrameSocket parses.
// FrameSocket keeps the mask, and tungstenite's unmasking is private, so the parsed frame
// is formatted once more: format XORs with the frame's mask, which undoes it.
use std::io::Cursor;
use std::time::Instant;
use tungstenite::protocol::frame::coding::{Data, OpCode};
use tungstenite::protocol::frame::{Frame, FrameSocket};

fn main() {
    let src: Vec<u8> = (0..65536u32).map(|i| (i * 7) as u8).collect();
    let t0 = Instant::now();
    let mut sum: u32 = 0;
    for _ in 0..256 {
        let mut f = Frame::message(src.clone(), OpCode::Data(Data::Binary), true);
        f.header_mut().mask = Some([0x37, 0xfa, 0x21, 0x3d]);
        let mut wire = Vec::new();
        f.format(&mut wire).unwrap();
        let (n, w) = (wire.len() as u32, wire[20] as u32);
        let got = FrameSocket::new(Cursor::new(wire)).read(None).unwrap().unwrap();
        let mut plain = Vec::with_capacity(n as usize);
        got.format(&mut plain).unwrap();
        sum = sum.wrapping_add(n + w + plain[plain.len() - 1] as u32);
    }
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("frame\t{ms:.3}\t{sum}");
}
