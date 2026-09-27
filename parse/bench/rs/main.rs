// Parser combinator benchmark in Rust: a JSON grammar on nom (see README.md).
use nom::{
    branch::alt,
    bytes::complete::{tag, take_while1, take_while_m_n},
    character::complete::{char, digit0, digit1, multispace0, one_of},
    combinator::{map, map_opt, opt, recognize, value},
    multi::{many0, separated_list0},
    sequence::{delimited, pair, preceded, separated_pair, terminated, tuple},
    IResult,
};
use std::collections::BTreeMap;
use std::time::Instant;

enum Val {
    Null,
    Flag(bool),
    Num(String),
    Str(String),
    Arr(Vec<Val>),
    Obj(BTreeMap<String, Val>),
}

fn ws<'a, O>(p: impl FnMut(&'a str) -> IResult<&'a str, O>) -> impl FnMut(&'a str) -> IResult<&'a str, O> {
    delimited(multispace0, p, multispace0)
}

fn number(i: &str) -> IResult<&str, String> {
    let int = alt((tag("0"), recognize(pair(one_of("123456789"), digit0))));
    let frac = opt(pair(char('.'), digit1));
    let exp = opt(tuple((one_of("eE"), opt(one_of("+-")), digit1)));
    map(recognize(tuple((opt(char('-')), int, frac, exp))), String::from)(i)
}

fn hex4(i: &str) -> IResult<&str, u32> {
    map_opt(take_while_m_n(4, 4, |c: char| c.is_ascii_hexdigit()), |h| u32::from_str_radix(h, 16).ok())(i)
}

fn escape(i: &str) -> IResult<&str, char> {
    preceded(
        char('\\'),
        alt((
            value('"', char('"')),
            value('\\', char('\\')),
            value('/', char('/')),
            value('\u{8}', char('b')),
            value('\u{c}', char('f')),
            value('\n', char('n')),
            value('\r', char('r')),
            value('\t', char('t')),
            map_opt(preceded(char('u'), hex4), char::from_u32),
        )),
    )(i)
}

fn string(i: &str) -> IResult<&str, String> {
    let plain = take_while1(|c: char| c != '"' && c != '\\' && c >= ' ');
    let piece = alt((map(escape, String::from), map(plain, String::from)));
    delimited(char('"'), map(many0(piece), |v: Vec<String>| v.concat()), char('"'))(i)
}

fn val(i: &str) -> IResult<&str, Val> {
    ws(alt((
        map(tag("null"), |_| Val::Null),
        map(tag("true"), |_| Val::Flag(true)),
        map(tag("false"), |_| Val::Flag(false)),
        map(number, Val::Num),
        map(string, Val::Str),
        map(delimited(char('['), separated_list0(char(','), val), ws(char(']'))), Val::Arr),
        map(
            delimited(
                char('{'),
                separated_list0(char(','), separated_pair(ws(string), char(':'), val)),
                ws(char('}')),
            ),
            |kv| Val::Obj(kv.into_iter().collect()),
        ),
    )))(i)
}

fn document(i: &str) -> IResult<&str, Val> {
    terminated(val, nom::combinator::eof)(i)
}

// Glue: compact JSON with sorted keys, as Json.encode prints it.
fn enc_str(s: &str, out: &mut String) {
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            '\u{8}' => out.push_str("\\b"),
            '\u{c}' => out.push_str("\\f"),
            c if c < ' ' => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
}

fn enc(v: &Val, out: &mut String) {
    match v {
        Val::Null => out.push_str("null"),
        Val::Flag(b) => out.push_str(if *b { "true" } else { "false" }),
        Val::Num(s) => out.push_str(s),
        Val::Str(s) => enc_str(s, out),
        Val::Arr(xs) => {
            out.push('[');
            for (i, x) in xs.iter().enumerate() {
                if i > 0 {
                    out.push(',');
                }
                enc(x, out);
            }
            out.push(']');
        }
        Val::Obj(m) => {
            out.push('{');
            for (i, (k, x)) in m.iter().enumerate() {
                if i > 0 {
                    out.push(',');
                }
                enc_str(k, out);
                out.push(':');
                enc(x, out);
            }
            out.push('}');
        }
    }
}

fn hash(s: &str) -> u32 {
    let mut h: u32 = 0;
    let mut n: u32 = 0;
    for c in s.chars() {
        h = h.wrapping_mul(31).wrapping_add(c as u32);
        n += 1;
    }
    h.wrapping_add(n)
}

fn main() {
    let doc = std::fs::read_to_string("out/doc.json").unwrap();
    let t0 = Instant::now();
    let (_, v) = document(&doc).expect("parse failed");
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    let mut out = String::new();
    enc(&v, &mut out);
    println!("parse\t{ms:.3}\t{}", hash(&out));
}
