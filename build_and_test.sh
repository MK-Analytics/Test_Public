#!/bin/bash

# ===========================================
#  MKA Test Package Builder + Deployment Test
# ===========================================
# Run this on your Mac. It will:
#   1. Build a .pkg that opens mk-analytics.com when installed
#   2. Print its SHA-256 hash
#   3. Give you upload instructions
#   4. Optionally test a public URL once uploaded
#
# Usage:
#   ./build_and_test.sh            # Build the .pkg
#   ./build_and_test.sh --test <URL>   # Test a public URL

MODE=$1
URL=$2

# -----------------------------------------------
# MODE 1: Build the .pkg (default)
# -----------------------------------------------
if [ -z "$MODE" ]; then

    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    BUILD_DIR="/tmp/mka_pkg_build"
    OUTPUT_PKG="$SCRIPT_DIR/MKASetup_test.pkg"

    echo "========================================="
    echo "  Step 1: Building MKA Test Package"
    echo "========================================="
    echo ""

    # Clean up any previous build
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR/root"
    mkdir -p "$BUILD_DIR/scripts"

    # Create postinstall script that opens mk-analytics.com
    cat > "$BUILD_DIR/scripts/postinstall" << 'EOF'
#!/bin/bash

# Open the MKA onboarding page for the current logged-in user
CURRENT_USER=$(stat -f "%Su" /dev/console)

if [ -n "$CURRENT_USER" ] && [ "$CURRENT_USER" != "root" ]; then
    sudo -u "$CURRENT_USER" open "https://mk-analytics.com"
fi

exit 0
EOF
    chmod +x "$BUILD_DIR/scripts/postinstall"

    # Build the .pkg
    pkgbuild \
        --root "$BUILD_DIR/root" \
        --scripts "$BUILD_DIR/scripts" \
        --identifier mka.onboarding.test2 \
        --version 1.0 \
        --install-location /tmp \
        "$OUTPUT_PKG"

    if [ $? -eq 0 ]; then
        echo ""
        echo "✅ Package built at: $OUTPUT_PKG"
    else
        echo "❌ pkgbuild failed. Make sure you're running this on a Mac."
        exit 1
    fi

    # Compute hash
    HASH=$(shasum -a 256 "$OUTPUT_PKG" | awk '{print $1}')
    echo "✅ SHA-256: $HASH"
    echo "   (Save this — you'll need it for ABM)"
    echo ""

    echo "========================================="
    echo "  Step 2: Upload to GitHub"
    echo "========================================="
    echo ""
    echo "  1. Go to your Test_Public repo on GitHub"
    echo "  2. Go to Releases → Edit your existing release"
    echo "  3. Delete the old MKASetup_test.pkg"
    echo "  4. Upload: $OUTPUT_PKG (same folder as this script)"
    echo "  5. Click Update release"
    echo ""
    echo "  Then update ABM with:"
    echo "  Bundle ID:  mka.onboarding.install"
    echo "  Version:    1.0"
    echo "  SHA-256:    $HASH"
    echo ""
    echo "========================================="
    echo "  Step 3: Test the URL"
    echo "========================================="
    echo ""
    echo "  Run:  ./build_and_test.sh --test <YOUR_URL>"
    echo ""

# -----------------------------------------------
# MODE 2: Test the uploaded URL
# -----------------------------------------------
elif [ "$MODE" == "--test" ] && [ -n "$URL" ]; then

    DOWNLOAD_PATH="/tmp/MKASetup_downloaded.pkg"

    echo "========================================="
    echo "  Testing Public URL"
    echo "========================================="
    echo ""

    # Check accessibility
    echo "Step 1: Checking URL accessibility..."
    HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" -L "$URL")

    if [ "$HTTP_STATUS" -eq 200 ]; then
        echo "✅ URL is publicly accessible (HTTP $HTTP_STATUS)"
    elif [ "$HTTP_STATUS" -eq 404 ]; then
        echo "❌ Got a 404 - repo may still be private, or the URL is wrong"
        exit 1
    else
        echo "❌ Unexpected HTTP status: $HTTP_STATUS"
        exit 1
    fi

    echo ""

    # Download
    echo "Step 2: Downloading file..."
    curl -L --progress-bar "$URL" -o "$DOWNLOAD_PATH"

    if [ $? -eq 0 ]; then
        echo "✅ Download complete"
    else
        echo "❌ Download failed"
        exit 1
    fi

    echo ""

    # Hash
    echo "Step 3: Computing SHA-256..."
    ACTUAL_HASH=$(shasum -a 256 "$DOWNLOAD_PATH" | awk '{print $1}')
    echo "✅ SHA-256: $ACTUAL_HASH"
    echo "   (Paste this into the ABM package hash field)"

    echo ""

    # Open
    echo "Step 4: Installing package..."
    sudo installer -pkg "$DOWNLOAD_PATH" -target /
    
    if [ $? -eq 0 ]; then
        echo "✅ Package installed — mk-analytics.com should open in your browser"
    else
        echo "❌ Installation failed"
        exit 1
    fi

    echo ""
    echo "========================================="
    echo "  ✅ All checks passed!"
    echo "  Update ABM with your real .pkg URL"
    echo "  when ready."
    echo "========================================="

else
    echo "Usage:"
    echo "  ./build_and_test.sh               # Build .pkg + upload instructions"
    echo "  ./build_and_test.sh --test <URL>  # Test a public URL"
fi