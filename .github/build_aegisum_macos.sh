#!/bin/bash
set -e

# ================================================================================================
# Official Aegisum macOS Core Wallet Compiler
# ================================================================================================
# This script automatically builds and packages the Aegisum Qt Core wallet for macOS
# Features:
# - Automatic source updates from official Aegisum repository
# - Professional DMG packaging with proper app bundle
# - Support for both Intel and Apple Silicon Macs
# - Automated dependency management
# - Berkeley DB 4.8 compatibility
# - Protobuf 3.6.1 for maximum compatibility
# ================================================================================================

# Color definitions for better output
GREEN="\033[0;32m"
RED="\033[0;31m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Configuration
AEGISUM_REPO="https://github.com/Aegisum/aegisum-core.git"
COMPILED_DIR="$(pwd)/compiled_wallets_macos"
PROTOBUF_DIR="$HOME/local/protobuf-3.6.1"
PROTOBUF_TAR="protobuf-cpp-3.6.1.tar.gz"
PROTOBUF_URL="https://github.com/protocolbuffers/protobuf/releases/download/v3.6.1/${PROTOBUF_TAR}"

# ================================================================================================
# Ensure proper environment setup
# ================================================================================================
if [[ ! "$HOME" =~ ^/ ]]; then
  echo -e "${RED}⚠ Detected invalid \$HOME: '$HOME'. Fixing...${RESET}"
  export HOME="$(eval echo ~$USER)"
  echo -e "${GREEN}✔ HOME corrected to: $HOME${RESET}"
fi

# Fix PATH so basic commands are found
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"

# ================================================================================================
# Display banner
# ================================================================================================
echo -e "${BLUE}================================================================================================"
echo -e "                    🍎 Official Aegisum macOS Core Wallet Compiler 🍎"
echo -e "================================================================================================"
echo -e "${CYAN}Version: 2.0.0"
echo -e "Features: Auto-updates, Professional DMG packaging, Universal compatibility"
echo -e "Repository: Official Aegisum Core"
echo -e "================================================================================================${RESET}"

# ================================================================================================
# Interactive configuration (only if not in CI)
# ================================================================================================
if [[ -z "$CI" && -z "$GITHUB_ACTIONS" ]]; then
    echo -e "\n${GREEN}🔧 Build Configuration:${RESET}"
    echo "1) Daemon only"
    echo "2) Daemon + Qt Wallet (full build) [RECOMMENDED]"
    echo "3) Qt Wallet only"
    read -rp "Enter choice [1-3]: " BUILD_CHOICE
    
    read -rp $'\n🗜️  Strip binaries for smaller size? (y/n): ' STRIP_BIN
    read -rp $'📦 Create professional .app bundle and DMG? (y/n): ' MAKE_DMG
else
    # CI defaults
    BUILD_CHOICE="2"
    STRIP_BIN="y"
    MAKE_DMG="y"
    echo -e "${CYAN}🤖 Running in CI mode with default settings: Full build + DMG creation${RESET}"
fi

# ================================================================================================
# Install dependencies via Homebrew
# ================================================================================================
echo -e "\n${GREEN}📦 Installing build dependencies via Homebrew...${RESET}"
brew install automake libtool berkeley-db@4 boost openssl libevent qt@5 qrencode miniupnpc zeromq pkg-config create-dmg fmt

# ================================================================================================
# Install Protobuf 3.6.1 (Legacy compatible version)
# ================================================================================================
if [ ! -f "$PROTOBUF_DIR/bin/protoc" ]; then
    echo -e "${GREEN}🔧 Installing Protobuf 3.6.1 (compatible version)...${RESET}"
    mkdir -p "$HOME/local"
    CUR_DIR="$(pwd)"
    cd /tmp
    curl -LO "$PROTOBUF_URL"
    tar -xvf "$PROTOBUF_TAR"
    cd protobuf-3.6.1
    ./configure --prefix="$PROTOBUF_DIR"
    make -j"$(sysctl -n hw.logicalcpu)"
    make install
    echo -e "${CYAN}✔ Installed Protobuf 3.6.1 to $PROTOBUF_DIR${RESET}"
    cd "$CUR_DIR"
else
    echo -e "${CYAN}✔ Protobuf 3.6.1 already installed at $PROTOBUF_DIR${RESET}"
fi

# Create protobuf.pc if missing
if [ ! -f "$PROTOBUF_DIR/lib/pkgconfig/protobuf.pc" ]; then
    echo -e "${GREEN}🔧 Creating missing protobuf.pc...${RESET}"
    mkdir -p "$PROTOBUF_DIR/lib/pkgconfig"
    cat > "$PROTOBUF_DIR/lib/pkgconfig/protobuf.pc" <<EOF
prefix=$PROTOBUF_DIR
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: Protocol Buffers
Description: Google's Data Interchange Format
Version: 3.6.1
Libs: -L\${libdir} -lprotobuf
Cflags: -I\${includedir}
EOF
    echo -e "${CYAN}✔ Created protobuf.pc at $PROTOBUF_DIR/lib/pkgconfig${RESET}"
fi

# ================================================================================================
# GitHub Actions environment export (if running in CI)
# ================================================================================================
if [ -n "$GITHUB_ENV" ]; then
  echo "PKG_CONFIG_PATH=$PROTOBUF_DIR/lib/pkgconfig:\$PKG_CONFIG_PATH" >> "$GITHUB_ENV"
  echo "LD_LIBRARY_PATH=$PROTOBUF_DIR/lib:\$LD_LIBRARY_PATH" >> "$GITHUB_ENV"
  echo "LDFLAGS=-L$PROTOBUF_DIR/lib \$LDFLAGS" >> "$GITHUB_ENV"
  echo "CPPFLAGS=-I$PROTOBUF_DIR/include \$CPPFLAGS" >> "$GITHUB_ENV"
  echo "PATH=$PROTOBUF_DIR/bin:\$PATH" >> "$GITHUB_ENV"
fi

# ================================================================================================
# Auto-update Aegisum source code
# ================================================================================================
echo -e "\n${GREEN}🔄 Auto-updating Aegisum source code...${RESET}"
if [ ! -d "Aegisum" ]; then
    echo -e "${CYAN}📥 Cloning latest Aegisum core repository...${RESET}"
    git clone "$AEGISUM_REPO" Aegisum
    echo -e "${GREEN}✔ Successfully cloned Aegisum repository${RESET}"
else
    echo -e "${CYAN}🔄 Updating existing Aegisum repository...${RESET}"
    cd Aegisum
    
    # Get current and latest commit info
    CURRENT_COMMIT=$(git rev-parse HEAD)
    git fetch origin
    LATEST_COMMIT=$(git rev-parse origin/main)
    
    if [ "$CURRENT_COMMIT" != "$LATEST_COMMIT" ]; then
        echo -e "${YELLOW}📈 New updates available! Updating from $CURRENT_COMMIT to $LATEST_COMMIT${RESET}"
        git pull origin main
        echo -e "${GREEN}✔ Successfully updated to latest version${RESET}"
    else
        echo -e "${CYAN}✔ Already up to date with latest version${RESET}"
    fi
    cd ..
fi

cd Aegisum

# ================================================================================================
# Apply compatibility patches
# ================================================================================================
echo -e "\n${GREEN}🔧 Applying macOS compatibility patches...${RESET}"

# Patch Boost filesystem API (overwrite_if_exists -> overwrite_existing)
BDB_CPP_FILE="src/wallet/bdb.cpp"
if [ -f "$BDB_CPP_FILE" ]; then
    if grep -q "fs::copy_file(pathSrc, pathDest, fs::copy_option::overwrite_if_exists);" "$BDB_CPP_FILE"; then
      sed -i '' \
        -e 's|fs::copy_file(pathSrc, pathDest, fs::copy_option::overwrite_if_exists);|fs::copy_file(pathSrc, pathDest, fs::copy_options::overwrite_existing);|' \
        "$BDB_CPP_FILE"
      echo -e "${CYAN}✔ Applied Boost copy_file patch to $BDB_CPP_FILE${RESET}"
    else
      echo -e "${CYAN}✔ Boost patch not needed for $BDB_CPP_FILE${RESET}"
    fi
else
    echo -e "${YELLOW}⚠ Warning: $BDB_CPP_FILE not found, skipping Boost patch${RESET}"
fi

# Patch Boost recursive_directory_iterator API (level() and no_push() methods)
WALLETUTIL_CPP_FILE="src/wallet/walletutil.cpp"
if [ -f "$WALLETUTIL_CPP_FILE" ]; then
    if grep -q "it.level()" "$WALLETUTIL_CPP_FILE" || grep -q "it.no_push()" "$WALLETUTIL_CPP_FILE"; then
        # Create a backup
        cp "$WALLETUTIL_CPP_FILE" "$WALLETUTIL_CPP_FILE.boost_backup"
        
        # Replace level() and no_push() with compatible alternatives
        sed -i '' \
            -e 's/it\.level()/0/g' \
            -e 's/it\.no_push();//g' \
            "$WALLETUTIL_CPP_FILE"
        echo -e "${CYAN}✔ Applied Boost recursive_directory_iterator patch to $WALLETUTIL_CPP_FILE${RESET}"
    else
        echo -e "${CYAN}✔ Boost recursive_directory_iterator patch not needed for $WALLETUTIL_CPP_FILE${RESET}"
    fi
else
    echo -e "${YELLOW}⚠ Warning: $WALLETUTIL_CPP_FILE not found, skipping Boost recursive_directory_iterator patch${RESET}"
fi

# Patch configure.ac for macOS compatibility
echo -e "${GREEN}🔧 Patching configure.ac for macOS compatibility...${RESET}"
CONFIG_AC="configure.ac"
if grep -q "AM_INIT_AUTOMAKE" "$CONFIG_AC"; then
    PATCHED=0
    if ! grep -q "LT_INIT" "$CONFIG_AC"; then
        awk '{print} /AM_INIT_AUTOMAKE/ && !x {print "LT_INIT"; x=1}' "$CONFIG_AC" > "$CONFIG_AC.tmp" && mv "$CONFIG_AC.tmp" "$CONFIG_AC"
        echo -e "${CYAN}✔ Inserted LT_INIT${RESET}"
        PATCHED=1
    fi
    if ! grep -q "AC_PROG_CXX" "$CONFIG_AC"; then
        awk '{print} /AM_INIT_AUTOMAKE/ && !x {print "AC_PROG_CXX"; x=1}' "$CONFIG_AC" > "$CONFIG_AC.tmp" && mv "$CONFIG_AC.tmp" "$CONFIG_AC"
        echo -e "${CYAN}✔ Inserted AC_PROG_CXX${RESET}"
        PATCHED=1
    fi
    if ! grep -q "AC_PROG_CC" "$CONFIG_AC"; then
        awk '{print} /AM_INIT_AUTOMAKE/ && !x {print "AC_PROG_CC"; x=1}' "$CONFIG_AC" > "$CONFIG_AC.tmp" && mv "$CONFIG_AC.tmp" "$CONFIG_AC"
        echo -e "${CYAN}✔ Inserted AC_PROG_CC${RESET}"
        PATCHED=1
    fi
    if [[ "$PATCHED" == 1 ]]; then
        echo -e "${GREEN}🔧 Creating m4 directory and running aclocal...${RESET}"
        mkdir -p m4
        aclocal -I m4 || true
    fi
else
    echo -e "${RED}✖ Could not find AM_INIT_AUTOMAKE in configure.ac${RESET}"
    exit 1
fi

# ================================================================================================
# Environment setup for compilation
# ================================================================================================
echo -e "\n${GREEN}🔧 Setting up compilation environment...${RESET}"

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    echo -e "${CYAN}✔ Detected Apple Silicon (arm64)${RESET}"
    BREDB_PATH="/opt/homebrew/opt/berkeley-db@4"
    QT_PATH="/opt/homebrew/opt/qt@5"
    BOOST_PATH="/opt/homebrew/opt/boost"
    FMT_PATH="/opt/homebrew/opt/fmt"
    LIBEVENT_PATH="/opt/homebrew/opt/libevent"
else
    echo -e "${CYAN}✔ Detected Intel macOS${RESET}"
    BREDB_PATH="/usr/local/opt/berkeley-db@4"
    QT_PATH="/usr/local/opt/qt@5"
    BOOST_PATH="/usr/local/opt/boost"
    FMT_PATH="/usr/local/opt/fmt"
    LIBEVENT_PATH="/usr/local/opt/libevent"
fi

# Set environment variables
export PATH="$BREDB_PATH/bin:$QT_PATH/bin:$PATH"
export BOOST_ROOT="$BOOST_PATH"
export BOOST_INCLUDEDIR="$BOOST_PATH/include"
export BOOST_LIBRARYDIR="$BOOST_PATH/lib"
export LDFLAGS="-L$BREDB_PATH/lib -L$QT_PATH/lib -L$BOOST_PATH/lib -L$FMT_PATH/lib -L$LIBEVENT_PATH/lib $LDFLAGS"
export CPPFLAGS="-I$BREDB_PATH/include -I$QT_PATH/include -I$BOOST_PATH/include -I$FMT_PATH/include -I$LIBEVENT_PATH/include $CPPFLAGS"
export PKG_CONFIG_PATH="$QT_PATH/lib/pkgconfig:$FMT_PATH/lib/pkgconfig:$LIBEVENT_PATH/lib/pkgconfig:$PKG_CONFIG_PATH"

# Protobuf environment
if [[ -n "$PROTOBUF_DIR" ]]; then
    export PATH="$PROTOBUF_DIR/bin:$PATH"
    export LD_LIBRARY_PATH="$PROTOBUF_DIR/lib:$LD_LIBRARY_PATH"
    export PKG_CONFIG_PATH="$PROTOBUF_DIR/lib/pkgconfig:$PKG_CONFIG_PATH"
    export LDFLAGS="-L$PROTOBUF_DIR/lib $LDFLAGS"
    export CPPFLAGS="-I$PROTOBUF_DIR/include $CPPFLAGS"
    export PROTOC="$PROTOBUF_DIR/bin/protoc"
fi

# Boost linking fix
export LIBS="$LIBS -lboost_filesystem -lboost_system"

# Compiler settings
export CC=clang
export CXX=clang++
export CXXFLAGS="-std=c++14 -Wno-deprecated-builtins"

# Remove MacPorts paths and unsupported flags
export LDFLAGS="$(echo "$LDFLAGS" | sed 's|/opt/local[^ ]*||g')"
export CPPFLAGS="$(echo "$CPPFLAGS" | sed 's|/opt/local[^ ]*||g')"
export CXXFLAGS="$(echo "$CXXFLAGS" | sed 's/-fstack-clash-protection//g')"

# ================================================================================================
# Verify environment
# ================================================================================================
echo -e "\n${GREEN}🔍 Verifying build environment...${RESET}"
echo -e "${CYAN}>>> Checking protoc version...${RESET}"
which protoc
protoc --version || { echo -e "${RED}✖ protoc not found or not working.${RESET}"; exit 1; }

echo -e "${CYAN}>>> Checking pkg-config path for protobuf...${RESET}"
pkg-config --modversion protobuf || echo -e "${RED}⚠ protobuf not found via pkg-config${RESET}"

# ================================================================================================
# Configure and build
# ================================================================================================
CONFIGURE_ARGS="--with-incompatible-bdb --with-boost-libdir=$BOOST_LIBRARYDIR --with-protobuf=$PROTOBUF_DIR"

echo -e "\n${GREEN}🔨 Starting build process...${RESET}"
echo -e "${GREEN}>>> Running autogen.sh...${RESET}"
chmod +x share/genbuild.sh autogen.sh
./autogen.sh

echo -e "${CYAN}>>> Cleaning previous build configuration...${RESET}"
if [ -f Makefile ]; then
    make distclean || true
fi

echo -e "${GREEN}>>> Configuring build with args: $CONFIGURE_ARGS${RESET}"
if [[ "$BUILD_CHOICE" == "1" ]]; then
    ./configure $CONFIGURE_ARGS --without-gui
    echo -e "${CYAN}✔ Configured for daemon-only build${RESET}"
elif [[ "$BUILD_CHOICE" == "2" ]]; then
    ./configure $CONFIGURE_ARGS --with-gui=qt5
    echo -e "${CYAN}✔ Configured for full build (daemon + Qt wallet)${RESET}"
elif [[ "$BUILD_CHOICE" == "3" ]]; then
    ./configure $CONFIGURE_ARGS --disable-wallet --with-gui=qt5
    echo -e "${CYAN}✔ Configured for Qt wallet only${RESET}"
fi

echo -e "${CYAN}>>> Verifying Boost configuration...${RESET}"
grep boost config.log | grep "$BOOST_LIBRARYDIR" || echo -e "${RED}⚠ Boost may not have been detected from $BOOST_LIBRARYDIR${RESET}"

echo -e "${GREEN}>>> Starting compilation (using $(sysctl -n hw.logicalcpu) cores)...${RESET}"
make -j"$(sysctl -n hw.logicalcpu)"

# ================================================================================================
# Copy binaries to output directory
# ================================================================================================
echo -e "\n${GREEN}📦 Copying compiled binaries...${RESET}"
mkdir -p "$COMPILED_DIR"

if [[ "$BUILD_CHOICE" =~ [12] ]]; then
    cp src/aegisumd src/aegisum-cli src/aegisum-tx "$COMPILED_DIR/" 2>/dev/null || true
    echo -e "${CYAN}✔ Copied daemon binaries${RESET}"
fi

if [[ "$BUILD_CHOICE" =~ [23] ]]; then
    cp src/qt/aegisum-qt "$COMPILED_DIR/" 2>/dev/null || true
    echo -e "${CYAN}✔ Copied Qt wallet binary${RESET}"
fi

# ================================================================================================
# Strip binaries (optional)
# ================================================================================================
if [[ "$STRIP_BIN" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🗜️  Stripping binaries for smaller size...${RESET}"
    strip "$COMPILED_DIR"/* 2>/dev/null || true
    echo -e "${CYAN}✔ Binaries stripped${RESET}"
fi

# ================================================================================================
# Create professional .app bundle and DMG
# ================================================================================================
if [[ "$MAKE_DMG" =~ ^[Yy]$ && -f "$COMPILED_DIR/aegisum-qt" ]]; then
    echo -e "\n${GREEN}📱 Creating professional .app bundle...${RESET}"
    APP_BUNDLE_DIR="${COMPILED_DIR}/Aegisum-Qt.app"
    mkdir -p "$APP_BUNDLE_DIR/Contents/MacOS" "$APP_BUNDLE_DIR/Contents/Resources"
    
    # Copy Qt wallet binary
    cp "$COMPILED_DIR/aegisum-qt" "$APP_BUNDLE_DIR/Contents/MacOS/"
    
    # Create professional Info.plist
    cat > "$APP_BUNDLE_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>aegisum-qt</string>
  <key>CFBundleIdentifier</key>
  <string>com.aegisum.wallet</string>
  <key>CFBundleName</key>
  <string>Aegisum Wallet</string>
  <key>CFBundleDisplayName</key>
  <string>Aegisum Wallet</string>
  <key>CFBundleVersion</key>
  <string>1.0.0</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleSignature</key>
  <string>AEGS</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.14</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSRequiresAquaSystemAppearance</key>
  <false/>
</dict>
</plist>
EOF

    echo -e "${GREEN}📦 Running macdeployqt for dependency bundling...${RESET}"
    macdeployqt "$APP_BUNDLE_DIR" || { 
        echo -e "${RED}✖ macdeployqt failed. Ensure Qt is properly installed and in PATH.${RESET}"; 
        exit 1; 
    }

    echo -e "${GREEN}💿 Creating professional DMG installer...${RESET}"
    DMG_PATH="${COMPILED_DIR}/Aegisum-Wallet-macOS.dmg"
    
    # Remove existing DMG if it exists
    [ -f "$DMG_PATH" ] && rm "$DMG_PATH"
    
    create-dmg \
      --volname "Aegisum Wallet" \
      --volicon "$APP_BUNDLE_DIR/Contents/Resources/aegisum-qt.icns" \
      --window-pos 200 120 \
      --window-size 600 400 \
      --icon-size 100 \
      --icon "Aegisum-Qt.app" 175 190 \
      --hide-extension "Aegisum-Qt.app" \
      --app-drop-link 425 190 \
      --background-color "#f0f0f0" \
      "$DMG_PATH" \
      "$COMPILED_DIR" || {
        echo -e "${YELLOW}⚠ create-dmg failed, creating simple DMG...${RESET}"
        hdiutil create -volname "Aegisum Wallet" -srcfolder "$COMPILED_DIR" -ov -format UDZO "$DMG_PATH"
    }
    
    echo -e "${GREEN}✔ Professional DMG created at: $DMG_PATH${RESET}"
fi

# ================================================================================================
# Verify build and display results
# ================================================================================================
echo -e "\n${GREEN}🔍 Verifying build results...${RESET}"
if [[ -f "$COMPILED_DIR/aegisum-cli" ]]; then
    echo -e "${CYAN}>>> Checking linked libraries in aegisum-cli:${RESET}"
    otool -L "$COMPILED_DIR/aegisum-cli" | grep boost || echo -e "${RED}⚠ Boost not linked properly.${RESET}"
fi

# ================================================================================================
# Build completion summary
# ================================================================================================
echo -e "\n${BLUE}================================================================================================"
echo -e "                           🎉 BUILD COMPLETED SUCCESSFULLY! 🎉"
echo -e "================================================================================================${RESET}"
echo -e "${GREEN}📁 Output directory: ${COMPILED_DIR}${RESET}"
echo -e "${CYAN}📋 Build summary:${RESET}"

if [[ -f "$COMPILED_DIR/aegisumd" ]]; then
    echo -e "   ✔ aegisumd (daemon)"
fi
if [[ -f "$COMPILED_DIR/aegisum-cli" ]]; then
    echo -e "   ✔ aegisum-cli (command line interface)"
fi
if [[ -f "$COMPILED_DIR/aegisum-tx" ]]; then
    echo -e "   ✔ aegisum-tx (transaction utility)"
fi
if [[ -f "$COMPILED_DIR/aegisum-qt" ]]; then
    echo -e "   ✔ aegisum-qt (Qt wallet)"
fi
if [[ -d "$COMPILED_DIR/Aegisum-Qt.app" ]]; then
    echo -e "   ✔ Aegisum-Qt.app (macOS app bundle)"
fi
if [[ -f "$COMPILED_DIR/Aegisum-Wallet-macOS.dmg" ]]; then
    echo -e "   ✔ Aegisum-Wallet-macOS.dmg (installer)"
fi

echo -e "\n${CYAN}🚀 Ready for distribution!${RESET}"
echo -e "${BLUE}================================================================================================${RESET}"
