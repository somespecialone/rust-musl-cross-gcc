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
    && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Let's Encrypt R3 CA certificate from https://letsencrypt.org/certificates/
COPY lets-encrypt-r3.crt /usr/local/share/ca-certificates
RUN update-ca-certificates

ARG TARGET
ENV RUST_MUSL_CROSS_TARGET=$TARGET
ARG RUST_MUSL_MAKE_CONFIG=config.mak

COPY $RUST_MUSL_MAKE_CONFIG /tmp/config.mak

RUN cd /tmp && \
    git clone --depth 1 https://github.com/richfelker/musl-cross-make.git && \
    cp /tmp/config.mak /tmp/musl-cross-make/config.mak && \
    cd /tmp/musl-cross-make && \
    export CFLAGS="-fPIC -g1 $CFLAGS" && \
    export TARGET=$TARGET && \
    if [ `dpkg --print-architecture` = 'armhf' ] && [ `uname -m` = 'aarch64' ]; then SETARCH=linux32; else SETARCH= ; fi && \
    $SETARCH make -j$(nproc) > /tmp/musl-cross-make.log && \
    $SETARCH make install >> /tmp/musl-cross-make.log && \
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

# pkg-config cross compilation support
ENV TARGET_PKG_CONFIG_ALLOW_CROSS=1
ENV TARGET_PKG_CONFIG_SYSROOT_DIR=$TARGET_HOME
ENV TARGET_PKG_CONFIG_PATH=$TARGET_HOME/lib/pkgconfig:/usr/local/musl/lib/pkgconfig
ENV TARGET_PKG_CONFIG_LIBDIR=$TARGET_PKG_CONFIG_PATH

# We'll build our libraries in subdirectories of /home/rust/libs.  Please
# clean up when you're done.
WORKDIR /home/rust/libs

RUN export CC=$TARGET_CC && \
    export C_INCLUDE_PATH=$TARGET_C_INCLUDE_PATH && \
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
    if [ `dpkg --print-architecture` = 'armhf' ]; then GNU_TARGET="armv7-unknown-linux-gnueabihf"; else GNU_TARGET=`uname -m`-unknown-linux-gnu; fi && \
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

# Build statically linked binaries for MIPS targets
ENV CARGO_TARGET_MIPS_UNKNOWN_LINUX_MUSL_RUSTFLAGS='-C target-feature=+crt-static'
ENV CARGO_TARGET_MIPSEL_UNKNOWN_LINUX_MUSL_RUSTFLAGS='-C target-feature=+crt-static'
ENV CARGO_TARGET_MIPS64_UNKNOWN_LINUX_MUSLABI64_RUSTFLAGS='-C target-feature=+crt-static'
ENV CARGO_TARGET_MIPS64EL_UNKNOWN_LINUX_MUSLABI64_RUSTFLAGS='-C target-feature=+crt-static'

# Install apt packages for C cross compiling depending on target
RUN sudo apt update -y && sudo apt install -y gcc-multilib gcc make musl-dev musl-tools
RUN if [ "$TARGET" = "armv7-unknown-linux-musleabihf" ]; then \
        sudo apt install -y libc6-dev-armhf-cross; \
    elif [ "$TARGET" = "armv7-unknown-linux-musleabi" ]; then \
        sudo apt install -y libc6-dev-armel-cross; \
    elif [ "$TARGET" = "arm-unknown-linux-musleabi" ]; then \
        sudo apt install -y libc6-dev-armel-cross; \
    elif [ "$TARGET" = "arm-unknown-linux-musleabihf" ]; then \
        sudo apt install -y libc6-dev-armhf-cross; \
    elif [ "$TARGET" = "aarch64-unknown-linux-musl" ]; then \
        sudo apt install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu libc6-dev-arm64-cross; \
    elif [ "$TARGET" = "i686-unknown-linux-musl" ]; then \
        sudo apt install -y g++-multilib; \
    elif [ "$TARGET" = "i586-unknown-linux-musl" ]; then \
        sudo apt install -y g++-multilib; \
    fi

# Set linkers
ENV CC=$TARGET_CC
ENV CXX=$TARGET_CXX

# armv7-unknown-linux-musleabihf
ENV CARGO_TARGET_ARMV7_UNKNOWN_LINUX_MUSLEABIHF_LINKER=$TARGET_CC

# armv7-unknown-linux-musleabi
ENV CARGO_TARGET_ARMV7_UNKNOWN_LINUX_MUSLEABI_LINKER=$TARGET_CC

# arm-unknown-linux-musleabi
ENV CARGO_TARGET_ARM_UNKNOWN_LINUX_MUSLEABI_LINKER=$TARGET_CC

# arm-unknown-linux-musleabihf
ENV CARGO_TARGET_ARM_UNKNOWN_LINUX_MUSLEABIHF_LINKER=$TARGET_CC

# aarch64-unknown-linux-musl
ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_MUSL_LINKER=$TARGET_CC

# i686-unknown-linux-musl
ENV CARGO_TARGET_I686_UNKNOWN_LINUX_MUSL_LINKER=$TARGET_CC

# i586-unknown-linux-musl
ENV CARGO_TARGET_I586_UNKNOWN_LINUX_MUSL_LINKER=$TARGET_CC

# Expect our source code to live in /home/rust/src
WORKDIR /home/rust/src
