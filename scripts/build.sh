#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"

echo "==> Configuring CMake (self-contained development mode)..."
cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" \
  -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/celestia" \
  -DINSTALL_QMLDIR="qml" \
  -DINSTALL_QSCONFDIR="." \
  -DINSTALL_LIBDIR="lib" \
  -DCMAKE_BUILD_TYPE=Debug \
  -G Ninja

echo ""
echo "==> Building..."
cmake --build "$BUILD_DIR" -j"$(nproc)"

echo ""
echo "==> Installing to $BUILD_DIR/celestia..."
cmake --install "$BUILD_DIR"

echo ""
echo "=============================================="
echo "  Build complete!"
echo "=============================================="
echo ""
echo "  Run from local build directory:"
echo "    QML2_IMPORT_PATH=$BUILD_DIR/celestia/qml \\"
echo "      qs -c $BUILD_DIR/celestia"
echo ""
echo "  Or deploy to ~/.config/quickshell/Celestia-Shell/:"
echo "    cmake --install \"$BUILD_DIR\" --prefix ~/.config/quickshell/Celestia-Shell"
echo "    QML2_IMPORT_PATH=~/.config/quickshell/Celestia-Shell/qml \\"
echo "      qs -c Celestia-Shell"
echo ""
echo "  Incremental build (C++ only):"
echo "    cmake --build \"$BUILD_DIR\" -j\"$(nproc)\""
echo "    cmake --install \"$BUILD_DIR\""
echo ""
