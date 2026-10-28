# syntax=docker/dockerfile:1

ARG DEBIAN_IMAGE=debian:trixie-slim

# Deployment build tools. Interactive tooling lives in .devcontainer/Dockerfile.
FROM ${DEBIAN_IMAGE} AS build
ENV DEBIAN_FRONTEND=noninteractive \
    CMAKE_GENERATOR=Ninja
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      build-essential \
      clang lld mold \
      cmake ninja-build \
      git ca-certificates curl \
      pkg-config file patchelf \
      zip unzip \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace

# Reproducible project build using the same public preset API as a host build.
ARG CMAKE_PRESET=app-release
COPY . .
RUN cmake --preset "${CMAKE_PRESET}" \
    && cmake --build --preset "${CMAKE_PRESET}" --parallel \
    && cmake --install "out/build/${CMAKE_PRESET}" --prefix /opt/boilerplate

# CI/test stage. Building this stage fails if the selected preset's CTest suite
# fails, but ordinary runtime image builds do not rerun tests implicitly.
FROM build AS test
ARG CMAKE_PRESET=app-release
RUN ctest --preset "${CMAKE_PRESET}" --output-on-failure

# Keep runtime glibc-based as well: a generic C++ boilerplate should not silently
# switch ABI/libc semantics between build and runtime images.
FROM ${DEBIAN_IMAGE} AS runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      libstdc++6 libgcc-s1 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /opt/boilerplate /opt/boilerplate
ENTRYPOINT ["/opt/boilerplate/bin/TEST_PROJECT"]
