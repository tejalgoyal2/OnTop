#!/bin/bash
# setup.sh — generates the Xcode project from project.yml and opens it.
# Run this once after cloning. Requires Xcode to be installed.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "→ Checking for Xcode..."
if ! xcode-select -p &>/dev/null || [ ! -d "$(xcode-select -p)/usr/bin" ]; then
    echo "✗ Xcode not found. Install it from the App Store, then re-run this script."
    exit 1
fi

echo "→ Checking for Homebrew..."
if ! command -v brew &>/dev/null; then
    echo "  Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for Apple Silicon
    if [ -f /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

echo "→ Checking for XcodeGen..."
if ! command -v xcodegen &>/dev/null; then
    echo "  Installing XcodeGen..."
    brew install xcodegen
fi

echo "→ Generating OnTop.xcodeproj..."
xcodegen generate

echo "→ Opening project in Xcode..."
open OnTop.xcodeproj

echo ""
echo "✓ Done! Xcode should now be open."
echo ""
echo "  Before building:"
echo "  1. Select your development team in Signing & Capabilities"
echo "  2. Build with ⌘B"
echo "  3. Run with ⌘R"
echo ""
echo "  First launch: grant Accessibility permission when prompted."
