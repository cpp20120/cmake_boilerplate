use std::{env, fs, process};

// CMake must generate this in this registration's Cargo target directory before
// Cargo compiles the crate. A clean harness/scenario build tests that dependency.
include!(concat!(env!("CARGO_TARGET_DIR"), "/bench_input.rs"));

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mode = args.first().map(String::as_str).unwrap_or("json");
    if mode == "invalid" {
        println!("deliberately invalid JSON");
        return;
    }
    if mode == "fail" {
        eprintln!("deliberate workload failure");
        process::exit(2);
    }
    let count: u64 = args.get(1).map(|s| s.parse().unwrap()).unwrap_or(4);
    assert!(count <= 10000, "fixture workload is bounded");
    let mut checksum: u64 = (1..=count).map(|n| n * INPUT_SCALE).sum();
    if mode == "unstable" {
        let path = args.get(2).expect("unstable mode requires a counter path");
        let counter: u64 = fs::read_to_string(path)
            .ok()
            .map(|s| s.parse().unwrap())
            .unwrap_or(0);
        fs::write(path, (counter + 1).to_string()).unwrap();
        checksum += counter;
    }
    if mode == "json-line" {
        println!("fixture workload: {count} items");
    }
    println!("{{\"status\":\"ok\",\"items\":{count},\"checksum\":{checksum}}}");
}
