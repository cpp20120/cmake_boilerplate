#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    // A small but actual libFuzzer target; integration tests use fake tools.
    let mut checksum = 0u64;
    for &byte in data {
        checksum = checksum.wrapping_mul(31).wrapping_add(u64::from(byte));
    }
    std::hint::black_box(checksum);
});
