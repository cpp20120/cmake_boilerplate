# syntax=docker/dockerfile:1

ARG DEBIAN_IMAGE=debian:trixie-slim

# Interactive development tools; deployment builds use the root Dockerfile.
FROM ${DEBIAN_IMAGE} AS dev
ENV DEBIAN_FRONTEND=noninteractive \
    CMAKE_GENERATOR=Ninja
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      build-essential \
      clang clangd clang-format clang-tidy clang-tools \
      llvm lld mold \
      cmake cmake-format ninja-build \
      ccache \
      git ca-certificates curl \
      python3 \
      pkg-config file patchelf \
      glslc glslang-tools \
      zip unzip \
      doxygen graphviz \
      cppcheck iwyu \
      gcovr lcov \
      gdb valgrind \
      afl++ \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace

# VS Code gets a non-root user; CLI shells can still select the dev stage.
FROM dev AS devcontainer
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      sudo lldb zsh zsh-autosuggestions zsh-syntax-highlighting \
      fzf zoxide ripgrep fd-find less \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 vscode \
    && useradd --uid 1000 --gid vscode --create-home --shell /bin/zsh vscode \
    && printf 'vscode ALL=(root) NOPASSWD:ALL\n' > /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode \
    && install -d -o vscode -g vscode /workspace/out
ENV CC=clang \
    CXX=clang++ \
    SHELL=/bin/zsh \
    CARGO_HOME=/home/vscode/.cargo \
    RUSTUP_HOME=/home/vscode/.rustup
ENV PATH="/home/vscode/.cargo/bin:${PATH}"
USER vscode
ARG RUST_TOOLCHAIN=stable
RUN curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs -o /tmp/rustup-init.sh \
    && sh /tmp/rustup-init.sh -y --no-modify-path --profile minimal \
      --default-toolchain "${RUST_TOOLCHAIN}" \
      --component clippy --component rustfmt --component rust-src \
    && rm /tmp/rustup-init.sh
# Debian's login profile resets PATH; retain Cargo for Bash login sessions too.
RUN printf '\n. "$HOME/.cargo/env"\n' >> /home/vscode/.profile
COPY --chown=vscode:vscode .devcontainer/zshrc /home/vscode/.zshrc
CMD ["/bin/zsh"]
