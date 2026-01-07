#!/bin/bash

# PRD Tool Build Script

set -e

echo "🔨 Building PRD Tool..."
echo ""

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "❌ Rust is not installed!"
    echo "Install Rust from: https://rustup.rs/"
    exit 1
fi

# Build in release mode
echo "Building release binaries..."
cargo build --release

# Check if build was successful
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "Binaries available at:"
    echo "  📦 Main CLI: target/release/prd"
    echo "  📊 Dashboard: target/release/prd-dashboard"
    echo ""
    echo "To use globally, add to your shell profile:"
    echo "  alias prd='$(pwd)/target/release/prd'"
    echo "  alias prd-dash='$(pwd)/target/release/prd-dashboard'"
    echo ""
    echo "Or create symlinks:"
    echo "  sudo ln -s $(pwd)/target/release/prd /usr/local/bin/prd"
    echo "  sudo ln -s $(pwd)/target/release/prd-dashboard /usr/local/bin/prd-dash"
else
    echo "❌ Build failed!"
    exit 1
fi
