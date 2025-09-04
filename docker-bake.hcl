group "default" {
  targets = [
    "armv7-musleabihf",
    "armv7-musleabi",
    "arm-musleabi",
    "arm-musleabihf",
    "aarch64-musl",
    "i686-musl",
    "i586-musl",
  ]
}

target "armv7-musleabihf" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  args = {
    TARGET = "armv7-unknown-linux-musleabihf"
  }
  tags = [
    "somespecialone/rust-musl-cross-gcc:armv7-musleabihf",
    "ghcr.io/somespecialone/rust-musl-cross-gcc:armv7-musleabihf",
  ]
}

target "armv7-musleabi" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  args = {
    TARGET = "armv7-unknown-linux-musleabi"
  }
  tags = [
    "somespecialone/rust-musl-cross-gcc:armv7-musleabi",
    "ghcr.io/somespecialone/rust-musl-cross-gcc:armv7-musleabi",
  ]
}

target "arm-musleabi" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  args = {
    TARGET = "arm-unknown-linux-musleabi"
  }
  tags = [
    "somespecialone/rust-musl-cross-gcc:arm-musleabi",
    "ghcr.io/somespecialone/rust-musl-cross-gcc:arm-musleabi",
  ]
}

target "arm-musleabihf" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  args = {
    TARGET = "arm-unknown-linux-musleabihf"
  }
  tags = [
    "somespecialone/rust-musl-cross-gcc:arm-musleabihf",
    "ghcr.io/somespecialone/rust-musl-cross-gcc:arm-musleabihf",
  ]
}

target "aarch64-musl" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  args = {
    TARGET = "aarch64-unknown-linux-musl"
    RUST_MUSL_MAKE_CONFIG = "config.aarch64.mak"
  }
  tags = [
    "somespecialone/rust-musl-cross-gcc:aarch64-musl",
    "ghcr.io/somespecialone/rust-musl-cross-gcc:aarch64-musl",
  ]
}

target "i686-musl" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  args = {
    TARGET = "i686-unknown-linux-musl"
  }
  tags = [
    "somespecialone/rust-musl-cross-gcc:i686-musl",
    "ghcr.io/somespecialone/rust-musl-cross-gcc:i686-musl",
  ]
}

target "i586-musl" {
  context = "."
  dockerfile = "Dockerfile"
  platforms = ["linux/amd64", "linux/arm64"]
  args = {
    TARGET = "i586-unknown-linux-musl"
  }
  tags = [
    "somespecialone/rust-musl-cross-gcc:i586-musl",
    "ghcr.io/somespecialone/rust-musl-cross-gcc:i586-musl",
  ]
}

