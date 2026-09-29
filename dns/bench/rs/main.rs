// DNS benchmark in Rust with hickory-proto: Message::to_vec builds, Message::from_vec parses. See README.md.
use hickory_proto::op::{Message, MessageType, OpCode, Query, ResponseCode};
use hickory_proto::rr::{DNSClass, Name, RData, RecordType};
use std::fmt::Write;
use std::time::Instant;

const TAIL: [u8; 47] = [
    0x81, 0x80, 0, 1, 0, 1, 0, 0, 0, 0, 3, b'w', b'w', b'w', 7, b'e', b'x', b'a', b'm', b'p', b'l', b'e', 3, b'c',
    b'o', b'm', 0, 0, 1, 0, 1, 0xc0, 0x0c, 0, 1, 0, 1, 0, 0, 0, 0x3c, 0, 4, 93, 184, 216, 34,
];

fn sum(b: &[u8], acc: u32) -> u32 {
    b.iter().fold(acc, |a, &x| a.wrapping_add(x as u32))
}

// The first A/IN record's address as dotted text, like Dns.answer.
fn answer(id: u16, msg: &[u8], out: &mut String) -> bool {
    let Ok(m) = Message::from_vec(msg) else { return false };
    if m.id != id || m.message_type != MessageType::Response || m.op_code != OpCode::Query || m.truncation
        || m.response_code != ResponseCode::NoError
    {
        return false;
    }
    for rr in &m.answers {
        if let (DNSClass::IN, RData::A(a)) = (rr.dns_class, &rr.data) {
            out.clear();
            write!(out, "{}", a.0).unwrap();
            return true;
        }
    }
    false
}

fn main() {
    let n: u32 = std::env::args().nth(1).map_or(100000, |s| s.parse().unwrap());

    let t0 = Instant::now();
    let mut chk = 0u32;
    for i in 0..n {
        let mut q = Message::new((i & 0xffff) as u16, MessageType::Query, OpCode::Query);
        q.metadata.recursion_desired = true;
        q.add_query(Query::query(Name::from_ascii("www.example.com").unwrap(), RecordType::A));
        chk = sum(&q.to_vec().unwrap(), chk);
    }
    println!("build\t{:.1}\t{chk}", t0.elapsed().as_secs_f64() * 1e3);

    let mut msg = [0u8; 49];
    msg[2..].copy_from_slice(&TAIL);
    let mut ip = String::with_capacity(15);
    let t0 = Instant::now();
    chk = 0;
    for i in 0..n {
        let id = (i & 0xffff) as u16;
        msg[..2].copy_from_slice(&id.to_be_bytes());
        if answer(id, &msg, &mut ip) {
            chk = sum(ip.as_bytes(), chk);
        }
    }
    println!("parse\t{:.1}\t{chk}", t0.elapsed().as_secs_f64() * 1e3);
}
