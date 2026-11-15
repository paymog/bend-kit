// CommonMark render benchmark: pulldown-cmark (see ../README.md).
use pulldown_cmark::{html, Options, Parser};
use std::time::Instant;

const N: usize = 100;
const R: usize = 10;

fn section(i: usize) -> String {
    format!(
        "## Section {i}\n\nSome *emphasis*, **strong**, `code <tag>`, and a [link](https://example.com/{i}?a=1&b=2 \"title {i}\").\n\
         Text with &amp; entities &lt; and <span class=\"x\">inline html</span>.\n\n\
         - item one\n- item two with `code`\n  - nested *item* {i}\n\n1. first\n2. second\n\n\
         > A quote with **bold** text\n> across lines.\n\n```python\ndef f(x):\n    return x < {i}\n```\n\n---\n\n"
    )
}

fn fnv(s: &[u8]) -> u32 {
    s.iter().fold(2166136261u32, |h, &b| (h ^ b as u32).wrapping_mul(16777619))
}

fn render(doc: &str) -> String {
    let mut out = String::new();
    html::push_html(&mut out, Parser::new_ext(doc, Options::empty()));
    out
}

fn main() {
    let doc: String = (0..N).map(section).collect();
    let chk = fnv(render(&doc).as_bytes());
    let t0 = Instant::now();
    let total: usize = (0..R).map(|_| render(&doc).len()).sum();
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("render\t{ms:.3}\t{chk}");
    println!("len\trender\t{total}");
}
