FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Make sure we have basic dev tools for building C libraries.  Our goal
# here is to support the musl-libc builds and Cargo builds needed for a
# large selection of the most popular crates.
#
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    cmake \
    curl \
    file \
    git \
    sudo \
    xutils-dev \
    unzip \
    ca-certificates \
    python3 \
    python3-pip \
    autoconf \
    autoconf-archive \
    automake \
    flex \
    bison \
    llvm-dev \
    libclang-dev \
    clang \
    musl-dev \
    musl-tools \
    pkg-config

# Install Let's Encrypt R3 CA certificate from https://letsencrypt.org/certificates/
COPY lets-encrypt-r3.crt /usr/local/share/ca-certificates
RUN update-ca-certificates

ARG TARGET=x86_64-unknown-linux-musl
ARG RUST_MUSL_MAKE_CONFIG=config.mak

ENV RUST_MUSL_CROSS_TARGET=$TARGET

COPY $RUST_MUSL_MAKE_CONFIG /tmp/config.mak

RUN cd /tmp && \
    git clone --depth 1 https://github.com/richfelker/musl-cross-make.git && \
    cp /tmp/config.mak /tmp/musl-cross-make/config.mak && \
    cd /tmp/musl-cross-make && \
    export CFLAGS="-fPIC -g1 $CFLAGS" && \
    make -j$(nproc) > /tmp/musl-cross-make.log && \
    make install >> /tmp/musl-cross-make.log && \
    ln -s /usr/local/musl/bin/$TARGET-strip /usr/local/musl/bin/musl-strip && \
    cd /tmp && \
    rm -rf /tmp/musl-cross-make /tmp/musl-cross-make.log

RUN mkdir -p /home/rust/libs /home/rust/src

# Set up our path with all our binary directories, including those for the
# musl-gcc toolchain and for our Rust toolchain.
ENV PATH=/root/.cargo/bin:/usr/local/musl/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV TARGET_CC=$TARGET-gcc
ENV TARGET_CXX=$TARGET-g++
ENV TARGET_AR=$TARGET-ar
ENV TARGET_RANLIB=$TARGET-ranlib
ENV TARGET_HOME=/usr/local/musl/$TARGET
ENV TARGET_C_INCLUDE_PATH=$TARGET_HOME/include/

# Set C & C++ linkers
ENV CC=$TARGET_CC
ENV CXX=$TARGET_CXX

# pkg-config cross compilation support
ENV TARGET_PKG_CONFIG_ALLOW_CROSS=1
ENV TARGET_PKG_CONFIG_SYSROOT_DIR=$TARGET_HOME
ENV TARGET_PKG_CONFIG_PATH=$TARGET_HOME/lib/pkgconfig:/usr/local/musl/lib/pkgconfig
ENV TARGET_PKG_CONFIG_LIBDIR=$TARGET_PKG_CONFIG_PATH

# We'll build our libraries in subdirectories of /home/rust/libs.  Please
# clean up when you're done.
WORKDIR /home/rust/libs

RUN export C_INCLUDE_PATH=$TARGET_C_INCLUDE_PATH && \
    export AR=$TARGET_AR && \
    export RANLIB=$TARGET_RANLIB && \
    echo "Building zlib" && \
    VERS=1.3.1 && \
    CHECKSUM=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23 && \
    cd /home/rust/libs && \
    curl -sqLO https://zlib.net/zlib-$VERS.tar.gz && \
    echo "$CHECKSUM zlib-$VERS.tar.gz" > checksums.txt && \
    sha256sum -c checksums.txt && \
    tar xzf zlib-$VERS.tar.gz && cd zlib-$VERS && \
    CFLAGS="-O3 -fPIC" ./configure --static --prefix=$TARGET_HOME && \
    make -j$(nproc) && make install && \
    cd .. && rm -rf zlib-$VERS.tar.gz zlib-$VERS checksums.txt

# The Rust toolchain to use when building our image
ARG TOOLCHAIN=stable
# Install our Rust toolchain and the `musl` target.  We patch the
# command-line we pass to the installer so that it won't attempt to
# interact with the user or fool around with TTYs.  We also set the default
# `--target` to musl so that our users don't need to keep overriding it
# manually.
# Chmod 755 is set for root directory to allow access execute binaries in /root/.cargo/bin (azure piplines create own user).
#
# Remove docs and more stuff not needed in this images to make them smaller
RUN chmod 755 /root/ && \
    GNU_TARGET=$(uname -m)-unknown-linux-gnu && \
    export RUSTUP_USE_CURL=1 && \
    curl https://sh.rustup.rs -sqSf | \
    sh -s -- -y --profile minimal --default-toolchain $TOOLCHAIN --default-host $GNU_TARGET && \
    rustup target add $TARGET || rustup component add --toolchain $TOOLCHAIN rust-src && \
    rustup component add --toolchain $TOOLCHAIN rustfmt clippy && \
    rm -rf /root/.rustup/toolchains/$TOOLCHAIN-$GNU_TARGET/share/

RUN echo "[target.$TARGET]\nlinker = \"$TARGET_CC\"\n" > /root/.cargo/config.toml

ENV RUSTUP_HOME=/root/.rustup
ENV CARGO_HOME=/root/.cargo
ENV CARGO_BUILD_TARGET=$TARGET

ENV CFLAGS_armv7_unknown_linux_musleabihf='-mfpu=vfpv3-d16'

# Cross-compiler toolchains depending on target and arch, hopeffuly enough to build most C libraries through cargo
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$TARGET" = "x86_64-unknown-linux-musl" ] && [ "$ARCH" = "arm64" ]; then \
      apt-get install -y libc6-dev-amd64-cross gcc-x86-64-linux-gnu g++-x86-64-linux-gnu; \
    elif [ "$TARGET" = "armv7-unknown-linux-musleabihf" ] || [ "$TARGET" = "arm-unknown-linux-musleabihf" ]; then \
      apt-get install -y libc6-dev-armhf-cross gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf; \
      if [ "$ARCH" = "amd64" ]; then \
        apt-get install -y gcc-multilib g++-multilib; \
      fi; \
    elif [ "$TARGET" = "armv7-unknown-linux-musleabi" ] || [ "$TARGET" = "arm-unknown-linux-musleabi" ]; then \
      apt-get install -y libc6-dev-armel-cross gcc-arm-linux-gnueabi g++-arm-linux-gnueabi; \
      if [ "$ARCH" = "amd64" ]; then \
        apt-get install -y gcc-multilib g++-multilib; \
      fi; \
    elif [ "$TARGET" = "aarch64-unknown-linux-musl" ] && [ "$ARCH" = "amd64" ]; then \
      apt-get install -y libc6-dev-arm64-cross gcc-aarch64-linux-gnu g++-aarch64-linux-gnu; \
    elif [ "$TARGET" = "i686-unknown-linux-musl" ] || [ "$TARGET" = "i586-unknown-linux-musl" ]; then \
      if [ "$ARCH" = "arm64" ]; then \
        apt-get install -y libc6-dev-i386-cross gcc-i686-linux-gnu g++-i686-linux-gnu; \
      else \
        apt-get install -y gcc-multilib g++-multilib; \
      fi; \
    fi

# clean apt lists for smaller image size
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Expect our source code to live in /home/rust/src
WORKDIR /home/rust/src
