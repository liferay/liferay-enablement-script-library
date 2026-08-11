#!/bin/bash
set -e

# Guard: if the current directory is no longer accessible (e.g., a previous
# run renamed or deleted it), bash cannot create subshells and the getcwd
# error becomes the first line of any pipeline output, breaking version checks.
# pwd is a shell builtin — it calls getcwd() without spawning a subprocess.
if ! pwd > /dev/null 2>&1; then
  echo "❌ Your current directory is no longer accessible."
  echo "   Please open a new terminal and re-run the command from a valid directory."
  exit 1
fi

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
  # The Azul API expects 'macos', not 'mac'
  local AZUL_OS="${OS}"
  [[ "$AZUL_OS" == "mac" ]] && AZUL_OS="macos"
  local ZULU_API_URL="https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?java_version=${JAVA_REQUIRED_VERSION}&os=${AZUL_OS}&arch=${ARCH}&ext=tar.gz&bundle_type=jre&javafx=false&release_status=ga&hw_bitness=64"
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

  persist_java_env
}

# Write JAVA_HOME persistently to the shell RC file so every new terminal
# session picks up Java 21 automatically — same behaviour as the Windows
# installer's SetEnvironmentVariable(User) call.
# Idempotent: removes any previous entry we wrote (detected by our stable
# marker path) before re-appending, so re-runs never accumulate duplicates.
persist_java_env() {
  # Target the canonical RC file for this OS; create it if absent.
  if [[ "$OS" == "mac" ]]; then
    local RC="${HOME}/.zshrc"
  else
    local RC="${HOME}/.bashrc"
  fi

  local MARKER=".liferay-course-runtime/zulu-java-21"

  # Remove any line from a previous run that references our managed JRE path.
  if grep -qF "$MARKER" "$RC" 2>/dev/null; then
    local _tmp_rc
    _tmp_rc=$(mktemp)
    grep -vF "$MARKER" "$RC" > "$_tmp_rc" || true
    mv "$_tmp_rc" "$RC"
  fi

  # Append a fresh entry. ${HOME} and $JAVA_HOME are written as literal text
  # (single-quoted printf) so the RC file is portable for any username — the
  # shell expands them when it sources the file on each new terminal session.
  {
    printf '\n# Added by Liferay Course Launcher\n'
    printf 'export JAVA_HOME="${HOME}/.liferay-course-runtime/zulu-java-21"\n'
    printf 'export PATH="$JAVA_HOME/bin:$PATH"\n'
  } >> "$RC"
  echo "📝 JAVA_HOME configured in $RC"
  echo "ℹ️  Run 'source $RC' or open a new terminal for the changes to take effect."
}

use_or_install_java() {
  # Prefer the managed per-user JRE if present (idempotent across runs)
  if [[ -x "$JAVA_DIR/bin/java" ]]; then
    export JAVA_HOME="$JAVA_DIR"
    export PATH="$JAVA_HOME/bin:$PATH"
    # Ensure the RC file is up to date even when Java was installed by a
    # previous run (e.g., the entry may be missing if the first run used an
    # older script version that only wrote to files that already existed).
    persist_java_env
    return
  fi

  # Install managed JRE — ensures JAVA_HOME is always explicitly set and
  # persisted to RC files regardless of any system Java that may be present.
  # Relying on an unmanaged system Java risks JAVA_HOME being unset when
  # Tomcat starts in a new terminal, causing cryptic JVM flag errors.
  install_zulu_jre
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

# Inject JAVA_HOME into Tomcat's setenv.sh so the server always starts with
# Java 21, regardless of the user's shell environment or RC file loading.
# catalina.sh sources setenv.sh automatically on every startup/shutdown.
# If initBundle already created a setenv.sh (Liferay uses it for JVM heap
# options), we prepend JAVA_HOME instead of overwriting the whole file.
_TOMCAT_STARTUP=$(find bundles -maxdepth 4 -name "startup.sh" 2>/dev/null | head -n1)
if [[ -n "$_TOMCAT_STARTUP" ]]; then
  _TOMCAT_BIN=$(dirname "$_TOMCAT_STARTUP")
  _SETENV="${_TOMCAT_BIN}/setenv.sh"
  # Write ${HOME}-relative paths for both JAVA_HOME and JRE_HOME so that
  # setenv.sh works for any user, not just the one who ran the installer.
  # Tomcat checks JRE_HOME first; if unset on macOS it falls back to
  # /usr/libexec/java_home which returns the system Java 8.
  # The single-quoted heredoc (<<'SETENV_JAVA') prevents ${HOME} from being
  # expanded now — the literal text is written into setenv.sh and expanded
  # by the shell when Tomcat sources the file at startup/shutdown.
  _TMP=$(mktemp)
  {
    cat <<'SETENV_JAVA'
export JAVA_HOME="${HOME}/.liferay-course-runtime/zulu-java-21"
export JRE_HOME="${HOME}/.liferay-course-runtime/zulu-java-21"
SETENV_JAVA
    if [[ -f "$_SETENV" ]]; then
      grep -v '^export JAVA_HOME=' "$_SETENV" \
        | grep -v '^export JRE_HOME=' \
        || true
    fi
  } > "$_TMP"
  mv "$_TMP" "$_SETENV"
  chmod +x "$_SETENV"
  echo "🔧 Configured Tomcat to use Java 21 (JAVA_HOME=$JAVA_HOME)"
fi

echo "✅ Done. Liferay bundle initialized. You may now start your Liferay application."
