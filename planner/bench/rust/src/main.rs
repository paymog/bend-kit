// Planner benchmark: petgraph::algo::toposort (see README.md).
use petgraph::algo::toposort;
use petgraph::graph::DiGraph;
use std::collections::HashMap;
use std::time::Instant;

fn main() {
    let rounds: u32 = std::env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(4);
    let n = 1000;
    let tasks: Vec<(String, Vec<String>)> = (0..n)
        .map(|i| (format!("n{i}"), (i + 1..(i + 4).min(n)).map(|j| format!("n{j}")).collect()))
        .collect();
    let mut chk: u32 = 0;
    let t0 = Instant::now();
    for _ in 0..rounds {
        let mut g = DiGraph::<&str, ()>::new();
        let mut ix = HashMap::new();
        for (node, _) in &tasks {
            ix.insert(node.as_str(), g.add_node(node.as_str()));
        }
        for (node, deps) in &tasks {
            for d in deps {
                g.add_edge(ix[d.as_str()], ix[node.as_str()], ());
            }
        }
        for i in toposort(&g, None).expect("acyclic") {
            chk = chk.wrapping_add(1 + g[i][1..].parse::<u32>().unwrap());
        }
    }
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("plan\t{ms:.3}\t{chk}");
}
