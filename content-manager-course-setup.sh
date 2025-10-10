#!/bin/bash
set -e

# === CONSTANTS ===
JAVA_REQUIRED_VERSION="21.0.1"
RUNTIME_DIR="${HOME}/.liferay-course-runtime"
JAVA_DIR="${RUNTIME_DIR}/zulu-java-21"

# === ARGUMENTS ===
if [[ $# -ne 2 ]]; then
  echo "❌ Wrong usage."
  echo "Usage:"
  echo "  bash -c \"\$(curl -fsSL <url>)\" -- --course1 mac"
  echo "  bash -c \"\$(curl -fsSL <url>)\" -- --course2 linux"
  exit 1
fi

COURSE_KEY="$1"
OS_INPUT="$2"

if [[ "$COURSE_KEY" == "--help" ]]; then
  echo "📚 Available options:"
  echo "  --course1     Install Backend Client Extensions course"
  echo "  --course2     Install Frontend Client Extensions course"
  echo "  --help        Show this help message"
  echo
  echo "📦 Example usage:"
  echo "  bash -c \"\$(curl -fsSL <url>)\" -- --course1 mac"
  exit 0
fi

case "$COURSE_KEY" in
  --publishing-tool-and-content-lifecycle)
    REPO_URL="https://github.com/liferay/liferay-course-publishing-tool-and-content-lifecycle/archive/refs/heads/main.zip"
    ;;
  --pages-navigation)
    REPO_URL="https://github.com/liferay/liferay-course-pages-navigation/archive/refs/heads/main.zip"
    ;;
  --search-engine-optimization)
    REPO_URL="https://github.com/liferay/liferay-course-search-engine-optimization/archive/refs/heads/main.zip"
    ;;
    --content-search)
    REPO_URL="https://github.com/liferay/liferay-course-content-search/archive/refs/heads/main.zip"
    ;;
    --personalized-experiences)
    REPO_URL="https://github.com/liferay/liferay-course-personalized-experiences/archive/refs/heads/main.zip"
    ;;
    --assets-and-content)
    REPO_URL="https://github.com/liferay/liferay-course-assets-and-content/archive/refs/heads/main.zip"
    ;;
    --building-enterprise-websites)
    REPO_URL="https://github.com/liferay/liferay-course-building-enterprise-websites/archive/refs/heads/master.zip"
    ;;
  *)
    echo "❌ Invalid course option: $COURSE_KEY"
    echo "Use: --course1 | --course2"
    exit 1
    ;;
esac

if [[ "$OS_INPUT" == "mac" || "$OS_INPUT" == "linux" ]]; then
  OS="$OS_INPUT"
else
  echo "❌ Invalid OS parameter: $OS_INPUT"
  echo "Use 'mac' or 'linux' as the second parameter."
  exit 1
fi

REPO_ZIP="repo.zip"

# === HELPERS ===
check_command() { command -v "$1" &>/dev/null; }

try_install() {
  local pkg="$1"
  if [[ "$OS" == "linux" ]]; then
    local DISTRO
    DISTRO=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
    echo "🔧 Installing $pkg..."
    if [[ "$DISTRO" =~ (ubuntu|debian) ]]; then
      sudo apt-get update && sudo apt-get install -y "$pkg"
    elif [[ "$DISTRO" =~ (fedora|centos|rhel) ]]; then
      sudo dnf install -y "$pkg" || sudo yum install -y "$pkg"
    else
      echo "⚠️ Unsupported Linux distro. Please install '$pkg' manually."
      exit 1
    fi
  else
    if ! check_command brew; then
      echo "❌ Homebrew not found. Install it manually."
      exit 1
    fi
    brew install "$pkg"
  fi
}

fetch() {
  local url="$1" output="$2"
  if check_command wget; then
    wget --show-progress -O "$output" "$url"
  elif check_command curl; then
    curl -# -L "$url" -o "$output"
  else
    try_install wget && wget --show-progress -O "$output" "$url"
  fi
}

fetch_text() {
  local url="$1"
  if check_command wget; then
    wget -qO- "$url"
  elif check_command curl; then
    curl -s "$url"
  else
    try_install wget && wget -qO- "$url"
  fi
}

install_zulu_jre() {
  local ARCH
  ARCH=$(uname -m)
  [[ "$ARCH" == "x86_64" ]] && ARCH="x64"
  [[ "$ARCH" =~ (arm64|aarch64) ]] && ARCH="aarch64"

  echo "🌐 Fetching Zulu JRE URL..."
  local ZULU_URL
  ZULU_URL=$(fetch_text "https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?java_version=${JAVA_REQUIRED_VERSION}&os=${OS}&arch=${ARCH}&ext=tar.gz&bundle_type=jre&javafx=false&release_status=ga&hw_bitness=64" \
    | grep -oE '"download_url"[ ]*:[ ]*"[^"]+"' | head -n 1 | cut -d '"' -f4)

  echo "⬇️ Downloading Zulu JRE..."
  mkdir -p "$JAVA_DIR"
  local TMP_TAR="${RUNTIME_DIR}/zulu.tar.gz"
  mkdir -p "$RUNTIME_DIR"
  fetch "$ZULU_URL" "$TMP_TAR"
  tar -xzf "$TMP_TAR" -C "$JAVA_DIR" --strip-components=1
  rm -f "$TMP_TAR"

  export JAVA_HOME="$JAVA_DIR"
  export PATH="$JAVA_HOME/bin:$PATH"
  echo "✅ Java installed at $JAVA_HOME"
  "$JAVA_HOME/bin/java" -version
}

use_or_install_java() {
  # Prefer the managed per-user JRE if present (idempotent across runs)
  if [[ -x "$JAVA_DIR/bin/java" ]]; then
    export JAVA_HOME="$JAVA_DIR"
    export PATH="$JAVA_HOME/bin:$PATH"
    return
  fi

  # Else, check system Java and version
  if check_command java; then
    local VER
    VER=$(java -version 2>&1 | head -n1 | grep -oE '"[0-9]+' | tr -d '"')
    if [[ "$VER" == "21" ]]; then
      # Use system Java 21
      return
    fi
  fi

  # Else, install our managed JRE 21
  install_zulu_jre
}

# === TOOLING ===
for cmd in unzip tar; do
  check_command "$cmd" || try_install "$cmd"
done

# === JAVA (idempotent across runs) ===
use_or_install_java

# === DOWNLOAD & EXTRACT REPO (no extra course folder) ===
echo "📦 Downloading course repository..."
fetch "$REPO_URL" "$REPO_ZIP"

# Determine top-level directory name from the zip BEFORE extracting
REPO_TOPDIR=$(unzip -Z -1 "$REPO_ZIP" | head -n1 | cut -d/ -f1)

# Rename to drop "-main" if present
CLEAN_NAME="${REPO_TOPDIR%-main}"

unzip -q "$REPO_ZIP"
rm "$REPO_ZIP"


# Remove existing target if it exists to avoid "move into dir"
if [[ -d "$CLEAN_NAME" && "$REPO_TOPDIR" != "$CLEAN_NAME" ]]; then
  rm -rf "$CLEAN_NAME"
fi

mv "$REPO_TOPDIR" "$CLEAN_NAME"
REPO_TOPDIR="$CLEAN_NAME"

# === INIT BUNDLE (inside the extracted repo) ===
cd "$REPO_TOPDIR"
echo "🛠 Setting up course environment..."
chmod +x ./gradlew || true
./gradlew initBundle

echo "✅ Done. Liferay bundle initialized. You may proceed to start your Liferay application now."