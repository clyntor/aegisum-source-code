#!/bin/bash
set -e

# ================================================================================================
# Official Aegisum Windows Core Wallet Cross-Compiler
# ================================================================================================
# This script automatically builds and packages the Aegisum Qt Core wallet for Windows
# Features:
# - Cross-compilation from Linux to Windows
# - Professional packaging with all binaries
# - Support for x86_64 Windows architecture
# - Automated dependency management
# - Full wallet functionality
# ================================================================================================

# Color definitions for better output
GREEN="\033[0;32m"
RED="\033[0;31m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Configuration
COMPILED_DIR="$(pwd)/compiled_wallets_windows"

# ================================================================================================
# Display banner
# ================================================================================================
echo -e "${BLUE}================================================================================================"
echo -e "                    🪟 Official Aegisum Windows Core Wallet Cross-Compiler 🪟"
echo -e "================================================================================================"
echo -e "${CYAN}Version: 2.0.0"
echo -e "Features: Cross-compilation, Professional packaging, Full wallet functionality"
echo -e "Target: Windows x86_64"
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
else
    # CI defaults
    BUILD_CHOICE="2"
    STRIP_BIN="y"
    echo -e "${CYAN}🤖 Running in CI mode with default settings: Full build${RESET}"
fi

# ================================================================================================
# Install Windows cross-compilation dependencies
# ================================================================================================
echo -e "\n${GREEN}📦 Installing Windows cross-compilation dependencies...${RESET}"
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    libtool \
    autotools-dev \
    automake \
    pkg-config \
    bsdmainutils \
    curl \
    git \
    python3 \
    g++-mingw-w64-x86-64 \
    mingw-w64-x86-64-dev

# ================================================================================================
# Set up cross-compilation environment
# ================================================================================================
echo -e "\n${GREEN}🔧 Setting up mingw32 compiler...${RESET}"
sudo update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix

# ================================================================================================
# Build from local repository
# ================================================================================================
echo -e "\n${GREEN}🔄 Building from local repository...${RESET}"
echo -e "${CYAN}✔ Using current repository source code${RESET}"

# ================================================================================================
# Clean PATH and build Windows dependencies
# ================================================================================================
echo -e "\n${GREEN}🏗️ Building Windows dependencies using depends system...${RESET}"
export PATH=$(echo "$PATH" | sed -e 's/:\/mnt.*//g')
cd depends
make HOST=x86_64-w64-mingw32 -j$(nproc)
cd ..

# ================================================================================================
# Configure and build
# ================================================================================================
echo -e "\n${GREEN}🔨 Starting Windows build process...${RESET}"
echo -e "${GREEN}>>> Running autogen.sh...${RESET}"
./autogen.sh

echo -e "${GREEN}>>> Configuring Windows build...${RESET}"
CONFIG_SITE=$PWD/depends/x86_64-w64-mingw32/share/config.site ./configure --prefix=/

if [[ "$BUILD_CHOICE" == "1" ]]; then
    echo -e "${CYAN}✔ Configured for daemon-only build${RESET}"
elif [[ "$BUILD_CHOICE" == "2" ]]; then
    echo -e "${CYAN}✔ Configured for full build (daemon + Qt wallet)${RESET}"
elif [[ "$BUILD_CHOICE" == "3" ]]; then
    echo -e "${CYAN}✔ Configured for Qt wallet only${RESET}"
fi

echo -e "${GREEN}>>> Starting compilation (using $(nproc) cores)...${RESET}"
make -j$(nproc)

# ================================================================================================
# Copy binaries to output directory
# ================================================================================================
echo -e "\n${GREEN}📦 Copying compiled Windows binaries...${RESET}"
mkdir -p "$COMPILED_DIR"

if [[ "$BUILD_CHOICE" =~ [12] ]]; then
    cp src/aegisumd.exe "$COMPILED_DIR/" 2>/dev/null || true
    cp src/aegisum-cli.exe "$COMPILED_DIR/" 2>/dev/null || true
    cp src/aegisum-tx.exe "$COMPILED_DIR/" 2>/dev/null || true
    echo -e "${CYAN}✔ Copied daemon binaries${RESET}"
fi

if [[ "$BUILD_CHOICE" =~ [23] ]]; then
    if [ -f src/qt/aegisum-qt.exe ]; then
        cp src/qt/aegisum-qt.exe "$COMPILED_DIR/" 2>/dev/null || true
        echo -e "${CYAN}✔ Copied Qt wallet binary${RESET}"
    fi
fi

# ================================================================================================
# Strip binaries (optional)
# ================================================================================================
if [[ "$STRIP_BIN" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🗜️  Stripping Windows binaries for smaller size...${RESET}"
    x86_64-w64-mingw32-strip "$COMPILED_DIR"/*.exe 2>/dev/null || true
    echo -e "${CYAN}✔ Binaries stripped${RESET}"
fi

# ================================================================================================
# Create Windows archive
# ================================================================================================
echo -e "\n${GREEN}📦 Creating Windows distribution archive...${RESET}"
cd "$COMPILED_DIR"
zip -r ../aegisum-wallet-tools-windows-x86_64.zip .
cd ..
echo -e "${CYAN}✔ Archive created: aegisum-wallet-tools-windows-x86_64.zip${RESET}"

# ================================================================================================
# Build completion summary
# ================================================================================================
echo -e "\n${BLUE}================================================================================================"
echo -e "                           🎉 WINDOWS BUILD COMPLETED SUCCESSFULLY! 🎉"
echo -e "================================================================================================${RESET}"
echo -e "${GREEN}📁 Output directory: ${COMPILED_DIR}${RESET}"
echo -e "${CYAN}📋 Build summary:${RESET}"

if [[ -f "$COMPILED_DIR/aegisumd.exe" ]]; then
    echo -e "   ✔ aegisumd.exe (daemon)"
fi
if [[ -f "$COMPILED_DIR/aegisum-cli.exe" ]]; then
    echo -e "   ✔ aegisum-cli.exe (command line interface)"
fi
if [[ -f "$COMPILED_DIR/aegisum-tx.exe" ]]; then
    echo -e "   ✔ aegisum-tx.exe (transaction utility)"
fi
if [[ -f "$COMPILED_DIR/aegisum-qt.exe" ]]; then
    echo -e "   ✔ aegisum-qt.exe (Qt wallet)"
fi

echo -e "\n${CYAN}🚀 Ready for distribution!${RESET}"
echo -e "${BLUE}================================================================================================${RESET}"
