#!/bin/bash
set -e

# ================================================================================================
# Official Aegisum Linux Core Wallet Compiler
# ================================================================================================
# This script automatically builds and packages the Aegisum Qt Core wallet for Linux
# Features:
# - Professional packaging with all binaries
# - Support for x86_64 architecture
# - Automated dependency management
# - Berkeley DB compatibility
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
COMPILED_DIR="$(pwd)/compiled_wallets_linux"

# ================================================================================================
# Display banner
# ================================================================================================
echo -e "${BLUE}================================================================================================"
echo -e "                    🐧 Official Aegisum Linux Core Wallet Compiler 🐧"
echo -e "================================================================================================"
echo -e "${CYAN}Version: 2.0.0"
echo -e "Features: Professional packaging, Full wallet functionality"
echo -e "Architecture: x86_64"
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
# Install dependencies
# ================================================================================================
echo -e "\n${GREEN}📦 Installing build dependencies...${RESET}"
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
    python3

# ================================================================================================
# Build from local repository
# ================================================================================================
echo -e "\n${GREEN}🔄 Building from local repository...${RESET}"
echo -e "${CYAN}✔ Using current repository source code${RESET}"

# ================================================================================================
# Clean PATH and build dependencies
# ================================================================================================
echo -e "\n${GREEN}🏗️ Building dependencies using depends system...${RESET}"
export PATH=$(echo "$PATH" | sed -e 's/:\/mnt.*//g')
cd depends
make HOST=x86_64-pc-linux-gnu -j$(nproc)
cd ..

# ================================================================================================
# Configure and build
# ================================================================================================
echo -e "\n${GREEN}🔨 Starting build process...${RESET}"
echo -e "${GREEN}>>> Running autogen.sh...${RESET}"
./autogen.sh

echo -e "${GREEN}>>> Configuring build...${RESET}"
CONFIG_SITE=$PWD/depends/x86_64-pc-linux-gnu/share/config.site ./configure --prefix=/

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
echo -e "\n${GREEN}📦 Copying compiled binaries...${RESET}"
mkdir -p "$COMPILED_DIR"

if [[ "$BUILD_CHOICE" =~ [12] ]]; then
    cp src/aegisumd "$COMPILED_DIR/" 2>/dev/null || true
    cp src/aegisum-cli "$COMPILED_DIR/" 2>/dev/null || true
    cp src/aegisum-tx "$COMPILED_DIR/" 2>/dev/null || true
    echo -e "${CYAN}✔ Copied daemon binaries${RESET}"
fi

if [[ "$BUILD_CHOICE" =~ [23] ]]; then
    if [ -f src/qt/aegisum-qt ]; then
        cp src/qt/aegisum-qt "$COMPILED_DIR/" 2>/dev/null || true
        echo -e "${CYAN}✔ Copied Qt wallet binary${RESET}"
    fi
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
# Create archive
# ================================================================================================
echo -e "\n${GREEN}📦 Creating distribution archive...${RESET}"
tar -czf aegisum-wallet-tools-linux-x86_64.tar.gz -C "$COMPILED_DIR" .
echo -e "${CYAN}✔ Archive created: aegisum-wallet-tools-linux-x86_64.tar.gz${RESET}"

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

echo -e "\n${CYAN}🚀 Ready for distribution!${RESET}"
echo -e "${BLUE}================================================================================================${RESET}"
