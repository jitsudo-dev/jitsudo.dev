#!/usr/bin/env sh
# install.sh — Install the jitsudo CLI
# Usage: curl -fsSL https://jitsudo.dev/install.sh | sh
# Override version: JITSUDO_VERSION=v0.3.0 curl -fsSL https://jitsudo.dev/install.sh | sh
set -eu

GITHUB_REPO="jitsudo-dev/jitsudo"
BINARY_NAME="jitsudo"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '  %s\n' "$*"; }

download() {
    url="$1"; dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$dest"
    else
        die "curl or wget is required to install jitsudo"
    fi
}

detect_platform() {
    os="$(uname -s)"; arch="$(uname -m)"
    case "$os" in
        Linux)  os="linux" ;;
        Darwin) os="darwin" ;;
        *)      die "Unsupported OS: $os (Windows users: see https://jitsudo.dev/docs/installation/)" ;;
    esac
    case "$arch" in
        x86_64)          arch="amd64" ;;
        aarch64 | arm64) arch="arm64" ;;
        *)               die "Unsupported architecture: $arch" ;;
    esac
    PLATFORM_OS="$os"; PLATFORM_ARCH="$arch"
}

verify_checksum() {
    binary_path="$1"; checksums_path="$2"; binary_filename="$3"
    expected=$(awk "\$NF == \"$binary_filename\" {print \$1}" "$checksums_path")
    [ -n "$expected" ] || die "Could not find checksum for $binary_filename in checksums.txt"
    if command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$binary_path" | awk '{print $1}')
    elif command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$binary_path" | awk '{print $1}')
    else
        info "Warning: no sha256 utility found — skipping checksum verification"
        return 0
    fi
    [ "$actual" = "$expected" ] || die "Checksum mismatch for $binary_filename"
    info "Checksum verified."
}

install_binary() {
    binary_path="$1"; binary_name="$2"
    install_dir="${INSTALL_PREFIX:-/usr/local}/bin"
    if [ -d "$install_dir" ] && [ -w "$install_dir" ]; then
        cp "$binary_path" "$install_dir/$binary_name"
        chmod 755 "$install_dir/$binary_name"
        info "Installed to $install_dir/$binary_name"
        return 0
    fi
    if [ -d "$install_dir" ] && command -v sudo >/dev/null 2>&1; then
        info "$install_dir is not writable — trying sudo..."
        if sudo cp "$binary_path" "$install_dir/$binary_name" && \
           sudo chmod 755 "$install_dir/$binary_name"; then
            info "Installed to $install_dir/$binary_name"
            return 0
        fi
    fi
    install_dir="$HOME/.local/bin"
    mkdir -p "$install_dir"
    cp "$binary_path" "$install_dir/$binary_name"
    chmod 755 "$install_dir/$binary_name"
    info "Installed to $install_dir/$binary_name"
    case ":$PATH:" in
        *":$install_dir:"*) ;;
        *)
            printf '\nNote: %s is not in your PATH.\n' "$install_dir"
            printf 'Add to your shell profile: export PATH="%s:$PATH"\n' "$install_dir"
            ;;
    esac
}

resolve_version() {
    if [ -n "${JITSUDO_VERSION:-}" ]; then VERSION="$JITSUDO_VERSION"; return; fi
    info "Fetching latest release version..."
    tmp_json="${WORK_DIR}/release.json"
    download "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" "$tmp_json"
    VERSION=$(grep '"tag_name"' "$tmp_json" | head -1 | \
              sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    [ -n "$VERSION" ] || die "Could not determine latest release version from GitHub API"
}

main() {
    printf '\n==> Installing jitsudo CLI\n\n'
    detect_platform
    info "Detected: ${PLATFORM_OS}/${PLATFORM_ARCH}"
    WORK_DIR="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$WORK_DIR'" EXIT
    resolve_version
    info "Version: $VERSION"
    BINARY_FILENAME="${BINARY_NAME}-${PLATFORM_OS}-${PLATFORM_ARCH}"
    BASE_URL="https://github.com/${GITHUB_REPO}/releases/download/${VERSION}"
    info "Downloading ${BINARY_FILENAME}..."
    download "${BASE_URL}/${BINARY_FILENAME}" "${WORK_DIR}/${BINARY_FILENAME}"
    info "Downloading checksums.txt..."
    download "${BASE_URL}/checksums.txt" "${WORK_DIR}/checksums.txt"
    verify_checksum "${WORK_DIR}/${BINARY_FILENAME}" "${WORK_DIR}/checksums.txt" "$BINARY_FILENAME"
    install_binary "${WORK_DIR}/${BINARY_FILENAME}" "$BINARY_NAME"
    printf '\njitsudo %s installed successfully.\n' "$VERSION"
    printf 'Run "jitsudo --help" to get started.\n\n'
}

[ "${JITSUDO_TEST:-0}" = "1" ] || main "$@"
