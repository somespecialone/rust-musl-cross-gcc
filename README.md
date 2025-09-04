# rust-musl-cross-gcc

[![Docker Image](https://img.shields.io/docker/pulls/somespecialone/rust-musl-cross-gcc.svg?maxAge=2592000)](https://hub.docker.com/r/somespecialone/rust-musl-cross-gcc/)
[![Build & Publish](https://github.com/somespecialone/rust-musl-cross-gcc/actions/workflows/ci.yml/badge.svg)](https://github.com/somespecialone/rust-musl-cross-gcc/actions/workflows/ci.yml)

Docker images for cross-compiling static **Rust and C binaries** with musl and GCC toolchains.

## Acknowledgements

This project is a _soft fork and based_ on [rust-cross/rust-musl-cross](https://github.com/rust-cross/rust-musl-cross).

> All modifications and maintenance in this repository are independent from the upstream project.

## Prebuilt images

Available [prebuilt Docker images on Docker Hub](https://hub.docker.com/r/somespecialone/rust-musl-cross-gcc/)
and [GitHub Packages](https://github.com/somespecialone/rust-musl-cross-gcc/pkgs/container/rust-musl-cross-gcc),
that supports **x86_64(amd64)** and **aarch64(arm64)** architectures:

| Cross Compile Target           | Docker Image Tag |
|--------------------------------|------------------|
| armv7-unknown-linux-musleabihf | armv7-musleabihf |
| armv7-unknown-linux-musleabi   | armv7-musleabi   |
| arm-unknown-linux-musleabi     | arm-musleabi     |
| arm-unknown-linux-musleabihf   | arm-musleabihf   |
| aarch64-unknown-linux-musl     | aarch64-musl     |
| i686-unknown-linux-musl        | i686-musl        |
| i586-unknown-linux-musl        | i586-musl        |

## How to use

Bind your source directory as volume to `/home/rust/src`

```sh
docker run --rm -v "$(pwd)":/home/rust/src ghcr.io/somespecialone/rust-musl-cross-gcc:armv7-musleabihf /bin/bash -c "cargo build --release"
```

This command assumes that `$(pwd)` is readable and writable. It will output binaries in `armv7-unknown-linux-musleabihf`

## How it works

`rust-musl-cross-gcc` provides Docker images with prebuilt musl-based toolchains, designed for cross-compiling both Rust
and C programs into static binaries. It builds on top of [musl-libc](http://www.musl-libc.org/),
[musl-gcc](http://www.musl-libc.org/how.html), and [musl-cross-make](https://github.com/richfelker/musl-cross-make),
bundling them together with Rust’s `rustup` target support.  
This makes it easy to produce lightweight, portable executables that run reliably across different Linux
distributions—without needing glibc or dynamic dependencies.

## Use beta/nightly Rust

Stable Rust installed by default, so if you want to switch to beta/nightly Rust, you can do it by extending
from `rust-musl-cross-gcc` Docker image.
Example to use beta Rust for target `aarch64-unknown-linux-musl `:

```dockerfile
FROM ghcr.io/somespecialone/rust-musl-cross-gcc:aarch64-musl
RUN rustup update beta && \
    rustup target add --toolchain beta aarch64-unknown-linux-musl 
```

## Strip binaries

You can use the `musl-strip` command inside the image to strip binaries, for example:

```bash
docker run --rm -it -v "$(pwd)":/home/rust/src ghcr.io/somespecialone/rust-musl-cross-gcc:aarch64-musl musl-strip /home/rust/src/target/release/example
```

## License

This project is licensed under either of:

- Apache License, Version 2.0, ([LICENSE-APACHE](LICENSE-APACHE.txt) or <http://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT.txt) or <http://opensource.org/licenses/MIT>)
- MIT license ([LICENSE](LICENSE) or <http://opensource.org/licenses/MIT>)

at your option.

### Copyright

- Original work © 2017–2025 rust-cross contributors
- Modifications © 2025 Somespecialone <itsme@somespecial.one>

Both the original work and modifications are licensed under the same [license](#license).
