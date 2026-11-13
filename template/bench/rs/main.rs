// Mustache render benchmark: the mustache crate (see ../README.md).
use mustache::MapBuilder;
use std::time::Instant;

const N: usize = 200;
const R: usize = 100;
const SRC: &str = "<ul>\n{{#items}}\n  <li><a href=\"{{url}}\">{{name}}</a>{{#tags}} [{{.}}]{{/tags}}</li>\n{{/items}}\n</ul>\n";

fn fnv(s: &[u8]) -> u32 {
    s.iter().fold(2166136261u32, |h, &b| (h ^ b as u32).wrapping_mul(16777619))
}

fn main() {
    let tpl = mustache::compile_str(SRC).unwrap();
    let data = MapBuilder::new()
        .insert_vec("items", |mut v| {
            for i in 0..N {
                v = v.push_map(|m| {
                    let tags: Vec<&str> = if i % 2 == 0 { vec!["new", "<hot>"] } else { vec![] };
                    m.insert_str("name", format!("Item {i} & co"))
                        .insert_str("url", format!("/items/{i}?a=1&b=\"2\""))
                        .insert("tags", &tags)
                        .unwrap()
                });
            }
            v
        })
        .build();
    let render = || {
        let mut out = Vec::new();
        tpl.render_data(&mut out, &data).unwrap();
        out
    };
    let chk = fnv(&render());
    let t0 = Instant::now();
    let total: usize = (0..R).map(|_| render().len()).sum();
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("render\t{ms:.3}\t{chk}");
    println!("len\trender\t{total}");
}
