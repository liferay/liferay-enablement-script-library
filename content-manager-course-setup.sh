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
    --classic-cms)
    REPO_URL="https://github.com/liferay/liferay-course-classic-cms/archive/refs/heads/main.zip"
    ;;
    --building-enterprise-websites)
    REPO_URL="https://github.com/liferay/liferay-course-building-enterprise-websites/archive/refs/heads/main.zip"
    ;;
    --foundations-of-commerce)
    REPO_URL="https://github.com/liferay/liferay-course-foundations-of-commerce/archive/refs/heads/main.zip"
    ;;
    --users-and-accounts)
    REPO_URL="https://github.com/liferay/liferay-course-commerce-users-and-accounts/archive/refs/heads/main.zip"
    ;;
    --product-management)
    REPO_URL="https://github.com/liferay/liferay-course-commerce-product-management/archive/refs/heads/main.zip"
    ;;
    --inventory-management)
    REPO_URL="https://github.com/liferay/liferay-course-commerce-inventory-management/archive/refs/heads/main.zip"
    ;;
    --pricing)
    REPO_URL="https://github.com/liferay/liferay-course-commerce-pricing/archive/refs/heads/main.zip"
    ;;
    --order-management)
    REPO_URL="https://github.com/liferay/liferay-course-commerce-order-management/archive/refs/heads/main.zip"
    ;;
    --storefronts)
    REPO_URL="https://github.com/liferay/liferay-course-commerce-storefronts/archive/refs/heads/main.zip"
    ;;
    --content-management-system)
    REPO_URL="https://github.com/liferay/liferay-course-content-management-system/archive/refs/heads/main.zip"
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
  local ZULU_API_URL="https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?java_version=${JAVA_REQUIRED_VERSION}&os=${OS}&arch=${ARCH}&ext=tar.gz&bundle_type=jre&javafx=false&release_status=ga&hw_bitness=64"
  local ZULU_API_RESPONSE ZULU_URL

  set +e
  ZULU_API_RESPONSE=$(fetch_text "$ZULU_API_URL")
  local FETCH_EXIT=$?
  set -e

  if [[ $FETCH_EXIT -ne 0 ]] || [[ -z "$ZULU_API_RESPONSE" ]]; then
    echo "❌ Could not reach the Azul API to fetch the Zulu JRE download URL."
    echo "   Endpoint: https://api.azul.com/zulu/download/community/v1.0/bundles/latest/"
    echo "   Please check your internet connection and try again."
    echo "   If the problem persists, contact support and share this message."
    exit 1
  fi

  ZULU_URL=$(echo "$ZULU_API_RESPONSE" \
    | grep -oE '"url"[ ]*:[ ]*"[^"]+\.tar\.gz"' | head -n 1 | cut -d '"' -f4)

  if [[ -z "$ZULU_URL" ]]; then
    echo "❌ The Azul API returned an unexpected response — no download URL found."
    echo "   Endpoint: https://api.azul.com/zulu/download/community/v1.0/bundles/latest/"
    echo "   The API may be temporarily unavailable or its format may have changed."
    echo "   Please try again later. If the problem persists, contact support and share this message."
    exit 1
  fi

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

  # Persist JAVA_HOME and PATH update for future sessions.
  # We check for our exact path, not just any JAVA_HOME, so that an existing
  # Java 8 entry in the file does not prevent writing — our entry appended
  # last takes precedence on the next shell load.
  for RC in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile"; do
    if [[ -f "$RC" ]] && ! grep -qF "JAVA_HOME=\"$JAVA_HOME\"" "$RC"; then
      printf '\nexport JAVA_HOME="%s"\nexport PATH="$JAVA_HOME/bin:$PATH"\n' "$JAVA_HOME" >> "$RC"
      echo "📝 Updated JAVA_HOME in $RC"
    fi
  done
  echo "ℹ️  Open a new terminal or run 'source ~/.bashrc' (or ~/.zshrc) for the PATH changes to take effect."
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
  # Defensive re-assertion: install_zulu_jre already exports these, but
  # repeating here guarantees the caller sees the correct values regardless
  # of any shell scoping edge case.
  export JAVA_HOME="$JAVA_DIR"
  export PATH="$JAVA_HOME/bin:$PATH"
}

# === TOOLING ===
for cmd in unzip tar; do
  check_command "$cmd" || try_install "$cmd"
done

# === JAVA (idempotent across runs) ===
use_or_install_java

# Verify that Java 21 is actually active before proceeding.
# Catches cases where JAVA_HOME was not propagated correctly (e.g. a system
# Java 8 override) and gives a clear, actionable message instead of the
# cryptic "--add-opens unrecognized option" error from the JVM.
_JAVA_BIN=""
if [[ -n "${JAVA_HOME:-}" ]] && [[ -x "${JAVA_HOME}/bin/java" ]]; then
  _JAVA_BIN="${JAVA_HOME}/bin/java"
elif command -v java &>/dev/null; then
  _JAVA_BIN="$(command -v java)"
fi
if [[ -z "$_JAVA_BIN" ]]; then
  echo "❌ No Java executable found after installation."
  echo "   Please open a new terminal and re-run the script."
  exit 1
fi
_JAVA_VER=$("$_JAVA_BIN" -version 2>&1 | head -n1 | grep -oE '"[0-9]+' | tr -d '"')
if [[ "$_JAVA_VER" != "21" ]]; then
  echo "❌ Java 21 is required, but the active version is ${_JAVA_VER:-unknown}."
  echo "   JAVA_HOME: ${JAVA_HOME:-not set}"
  echo "   Java binary: $_JAVA_BIN"
  echo "   If Java 21 was just installed, open a new terminal and re-run the script."
  exit 1
fi

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