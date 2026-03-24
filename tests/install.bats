#!/usr/bin/env bats
# Tests for public/install.sh
# Run with: bats tests/install.bats
# Requires bats-core: brew install bats-core  OR  sudo apt-get install bats

setup() {
    export JITSUDO_TEST=1
    # shellcheck disable=SC1090
    . "${BATS_TEST_DIRNAME}/../public/install.sh"
}

# ---------------------------------------------------------------------------
# detect_platform
# ---------------------------------------------------------------------------

@test "detect_platform: Linux x86_64 -> linux/amd64" {
    uname() { case "$1" in -s) echo "Linux" ;; -m) echo "x86_64" ;; esac; }
    detect_platform
    [ "$PLATFORM_OS"   = "linux" ]
    [ "$PLATFORM_ARCH" = "amd64" ]
}

@test "detect_platform: Darwin arm64 -> darwin/arm64" {
    uname() { case "$1" in -s) echo "Darwin" ;; -m) echo "arm64" ;; esac; }
    detect_platform
    [ "$PLATFORM_OS"   = "darwin" ]
    [ "$PLATFORM_ARCH" = "arm64" ]
}

@test "detect_platform: Darwin x86_64 -> darwin/amd64" {
    uname() { case "$1" in -s) echo "Darwin" ;; -m) echo "x86_64" ;; esac; }
    detect_platform
    [ "$PLATFORM_OS"   = "darwin" ]
    [ "$PLATFORM_ARCH" = "amd64" ]
}

@test "detect_platform: Linux aarch64 -> linux/arm64" {
    uname() { case "$1" in -s) echo "Linux" ;; -m) echo "aarch64" ;; esac; }
    detect_platform
    [ "$PLATFORM_OS"   = "linux" ]
    [ "$PLATFORM_ARCH" = "arm64" ]
}

@test "detect_platform: unsupported OS exits non-zero" {
    uname() { case "$1" in -s) echo "FreeBSD" ;; -m) echo "x86_64" ;; esac; }
    run detect_platform
    [ "$status" -ne 0 ]
}

@test "detect_platform: unsupported arch exits non-zero" {
    uname() { case "$1" in -s) echo "Linux" ;; -m) echo "i386" ;; esac; }
    run detect_platform
    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# verify_checksum
# ---------------------------------------------------------------------------

_make_checksums() {
    # Creates a test binary and a matching checksums.txt in $1.
    # Usage: _make_checksums <dir> <filename>
    dir="$1"; filename="$2"
    printf 'test binary content\n' > "$dir/$filename"
    if command -v sha256sum >/dev/null 2>&1; then
        # sha256sum outputs: <hash>  <path> — strip the dir prefix
        sha256sum "$dir/$filename" | awk -v f="$filename" '{print $1 "  " f}' > "$dir/checksums.txt"
    else
        shasum -a 256 "$dir/$filename" | awk -v f="$filename" '{print $1 "  " f}' > "$dir/checksums.txt"
    fi
}

@test "verify_checksum: passes with correct hash" {
    tmpdir="$(mktemp -d)"
    _make_checksums "$tmpdir" "jitsudo-linux-amd64"
    run verify_checksum "$tmpdir/jitsudo-linux-amd64" "$tmpdir/checksums.txt" "jitsudo-linux-amd64"
    [ "$status" -eq 0 ]
    rm -rf "$tmpdir"
}

@test "verify_checksum: fails when hash is wrong" {
    tmpdir="$(mktemp -d)"
    printf 'test binary content\n' > "$tmpdir/jitsudo-linux-amd64"
    printf '0000000000000000000000000000000000000000000000000000000000000000  jitsudo-linux-amd64\n' \
        > "$tmpdir/checksums.txt"
    run verify_checksum "$tmpdir/jitsudo-linux-amd64" "$tmpdir/checksums.txt" "jitsudo-linux-amd64"
    [ "$status" -ne 0 ]
    rm -rf "$tmpdir"
}

@test "verify_checksum: fails when filename not in checksums" {
    tmpdir="$(mktemp -d)"
    printf 'test binary content\n' > "$tmpdir/jitsudo-linux-amd64"
    printf 'abc123  some-other-file\n' > "$tmpdir/checksums.txt"
    run verify_checksum "$tmpdir/jitsudo-linux-amd64" "$tmpdir/checksums.txt" "jitsudo-linux-amd64"
    [ "$status" -ne 0 ]
    rm -rf "$tmpdir"
}

@test "verify_checksum: awk pattern does not match daemon binary name" {
    # jitsudod-linux-amd64 must not satisfy a check for jitsudo-linux-amd64
    tmpdir="$(mktemp -d)"
    printf 'daemon binary\n' > "$tmpdir/jitsudod-linux-amd64"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$tmpdir/jitsudod-linux-amd64" | awk '{print $1 "  jitsudod-linux-amd64"}' \
            > "$tmpdir/checksums.txt"
    else
        shasum -a 256 "$tmpdir/jitsudod-linux-amd64" | awk '{print $1 "  jitsudod-linux-amd64"}' \
            > "$tmpdir/checksums.txt"
    fi
    # No entry for "jitsudo-linux-amd64" (only "jitsudod-linux-amd64")
    run verify_checksum "$tmpdir/jitsudod-linux-amd64" "$tmpdir/checksums.txt" "jitsudo-linux-amd64"
    [ "$status" -ne 0 ]
    rm -rf "$tmpdir"
}

# ---------------------------------------------------------------------------
# install_binary
# ---------------------------------------------------------------------------

@test "install_binary: installs to writable INSTALL_PREFIX" {
    tmpdir="$(mktemp -d)"
    mkdir -p "$tmpdir/bin"
    printf '#!/bin/sh\necho jitsudo\n' > "$tmpdir/jitsudo-linux-amd64"
    chmod +x "$tmpdir/jitsudo-linux-amd64"
    INSTALL_PREFIX="$tmpdir" install_binary "$tmpdir/jitsudo-linux-amd64" "jitsudo"
    [ -x "$tmpdir/bin/jitsudo" ]
    rm -rf "$tmpdir"
}

@test "install_binary: falls back to ~/.local/bin when INSTALL_PREFIX does not exist" {
    tmpdir="$(mktemp -d)"
    # Use a non-existent prefix so both -d checks in install_binary fail,
    # bypassing the writable-check path and the sudo path entirely.
    # A chmod 555 approach fails on CI because passwordless sudo can still
    # write to a 555 directory, preventing the fallback from triggering.
    fake_prefix="$tmpdir/nonexistent"

    printf '#!/bin/sh\necho jitsudo\n' > "$tmpdir/jitsudo-linux-amd64"
    chmod +x "$tmpdir/jitsudo-linux-amd64"

    # Point HOME to a temp dir so ~/.local/bin is isolated
    old_home="$HOME"
    HOME="$tmpdir"
    INSTALL_PREFIX="$fake_prefix" run install_binary "$tmpdir/jitsudo-linux-amd64" "jitsudo"
    HOME="$old_home"

    [ "$status" -eq 0 ]
    [ -x "$tmpdir/.local/bin/jitsudo" ]

    rm -rf "$tmpdir"
}

# ---------------------------------------------------------------------------
# resolve_version
# ---------------------------------------------------------------------------

@test "resolve_version: uses JITSUDO_VERSION override without network" {
    WORK_DIR="$(mktemp -d)"
    JITSUDO_VERSION="v1.2.3" resolve_version
    [ "$VERSION" = "v1.2.3" ]
    rm -rf "$WORK_DIR"
}

# ---------------------------------------------------------------------------
# version JSON parsing
# ---------------------------------------------------------------------------

@test "version JSON parsing: extracts tag_name from GitHub API response" {
    tmpdir="$(mktemp -d)"
    cat > "$tmpdir/release.json" <<'JSON'
{
  "url": "https://api.github.com/repos/jitsudo-dev/jitsudo/releases/1",
  "tag_name": "v0.5.0",
  "name": "jitsudo v0.5.0",
  "draft": false,
  "prerelease": false
}
JSON
    version=$(grep '"tag_name"' "$tmpdir/release.json" | head -1 | \
              sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    [ "$version" = "v0.5.0" ]
    rm -rf "$tmpdir"
}

@test "version JSON parsing: handles compact JSON (no spaces around colon)" {
    tmpdir="$(mktemp -d)"
    printf '{"tag_name":"v1.0.0","name":"jitsudo v1.0.0"}\n' > "$tmpdir/release.json"
    version=$(grep '"tag_name"' "$tmpdir/release.json" | head -1 | \
              sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    [ "$version" = "v1.0.0" ]
    rm -rf "$tmpdir"
}
