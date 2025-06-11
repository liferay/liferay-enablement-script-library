#!/bin/bash

set -e

# === CONFIGURATION BASE ===
BASE_DIR="liferay-course-content-manager"
JAVA_REQUIRED_VERSION="21.0.1"

# === VALIDATE ARGUMENT ===
if [[ $# -ne 1 ]]; then
    echo "❌ Wrong URL or invalid parameter"
    exit 1
fi

COURSE_KEY="$1"

if [[ "$COURSE_KEY" == "--help" ]]; then
    echo "📚 Available options:"
    echo "  --course1     Install Backend Client Extensions course"
    echo "  --course2     Install Frontend Client Extensions course"
    echo "  --help        Show this help message"
    exit 0
fi

case "$COURSE_KEY" in
    --course1)
        REPO_URL="https://github.com/liferay/liferay-course-backend-client-extensions/archive/refs/heads/main.zip"
        ;;
    --course2)
        REPO_URL="https://github.com/liferay/liferay-course-frontend-client-extensions/archive/refs/heads/main.zip"
        ;;
    *)
        echo "❌ Invalid option: $COURSE_KEY"
        echo "Usage: --course1 | --course2"
        exit 1
        ;;
esac

REPO_ZIP="repo.zip"
REPO_DIR_NAME="${COURSE_KEY/--/}"  # e.g., course1 -> course-1
COURSE_DIR="${BASE_DIR}-${REPO_DIR_NAME}"

# === ASK FOR OS ===
echo "Which operating system are you using?"
echo "1) macOS"
echo "2) Linux"
read -rp "Enter the number (1 or 2): " os_choice

if [[ "$os_choice" == "1" ]]; then
    OS="mac"
elif [[ "$os_choice" == "2" ]]; then
    OS="linux"
else
    echo "❌ Invalid choice. Please enter 1 or 2."
    exit 1
fi

function check_command {
    command -v "$1" &>/dev/null
}

function try_install {
    local pkg="$1"
    if [[ "$OS" == "linux" ]]; then
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
    elif [[ "$OS" == "mac" ]]; then
        if ! check_command brew; then
            echo "❌ Homebrew not found. Install it manually."
            exit 1
        fi
        brew install "$pkg"
    fi
}

function fetch {
    local url="$1"
    local output="$2"
    if check_command wget; then
        wget --show-progress -O "$output" "$url"
    elif check_command curl; then
        curl -# -L "$url" -o "$output"
    else
        try_install wget && wget --show-progress -O "$output" "$url"
    fi
}

function fetch_text {
    local url="$1"
    if check_command wget; then
        wget -qO- "$url"
    elif check_command curl; then
        curl -s "$url"
    else
        try_install wget && wget -qO- "$url"
    fi
}

function install_zulu_jre {
    ARCH=$(uname -m)
    [[ "$ARCH" == "x86_64" ]] && ARCH="x64"
    [[ "$ARCH" =~ (arm64|aarch64) ]] && ARCH="aarch64"

    echo "🌐 Fetching Zulu JRE URL..."
    ZULU_URL=$(fetch_text "https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?java_version=${JAVA_REQUIRED_VERSION}&os=${OS}&arch=${ARCH}&ext=tar.gz&bundle_type=jre&javafx=false&release_status=ga&hw_bitness=64" | grep -oE '"download_url"[ ]*:[ ]*"[^"]+"' | head -n 1 | cut -d '"' -f4)

    echo "⬇️ Downloading Zulu JRE..."
    mkdir -p "$BASE_DIR/zulu-java"
    fetch "$ZULU_URL" "$BASE_DIR/zulu.tar.gz"
    tar -xzf "$BASE_DIR/zulu.tar.gz" -C "$BASE_DIR/zulu-java" --strip-components=1
    rm "$BASE_DIR/zulu.tar.gz"

    export JAVA_HOME="$(pwd)/$BASE_DIR/zulu-java"
    export PATH="$JAVA_HOME/bin:$PATH"
    echo "✅ Java installed at $JAVA_HOME"
    java -version
}

# === CREATE BASE & COURSE DIR ===
mkdir -p "$COURSE_DIR"
cd "$COURSE_DIR"

# === CHECK TOOLS ===
for cmd in unzip tar; do
    check_command "$cmd" || try_install "$cmd"
done

# === JAVA CHECK ===
INSTALL_ZULU=false
if check_command java; then
    JAVA_VERSION_OUTPUT=$(java -version 2>&1 | head -n 1)
    JAVA_MAJOR_VERSION=$(echo "$JAVA_VERSION_OUTPUT" | grep -oE '"[0-9]+' | tr -d '"')
    [[ "$JAVA_MAJOR_VERSION" != "21" ]] && INSTALL_ZULU=true
else
    INSTALL_ZULU=true
fi

if [[ "$INSTALL_ZULU" == true ]]; then
    install_zulu_jre
fi

# === DOWNLOAD REPO ===
echo "📦 Downloading course repository..."
fetch "$REPO_URL" "$REPO_ZIP"
unzip -q "$REPO_ZIP"
rm "$REPO_ZIP"

INNER_DIR=$(find . -maxdepth 1 -type d -name "*" ! -name "." | head -n 1)
mv "$INNER_DIR"/* .
rm -rf "$INNER_DIR"

# === INIT BUNDLE ===
echo "🛠 Setting up course environment..."
chmod +x ./gradlew || true
./gradlew initBundle

# === START LIFERAY ===
echo "🚀 Starting Liferay instance..."
cd bundles/tomcat*/bin
./catalina.sh run
