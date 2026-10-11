#![allow(unknown_lints)]
#![allow(unexpected_cfgs)]

#[cfg(not(feature = "answer"))]
compile_error!("the CMake registration must supply the answer feature");
#[cfg(feature = "unwanted")]
compile_error!("the CMake registration must disable default features");
#[cfg(not(cmake_fixture = "value with spaces"))]
compile_error!("build and test must preserve the structured RUSTFLAGS argument");

pub fn answer() -> u32 {
    42
}

#[cfg(test)]
mod tests {
    #[test]
    fn returns_answer() {
        assert_eq!(super::answer(), 42);
    }
}
