#!/bin/bash

# ===========================================
#  MKA Test Package Builder + Deployment Test
# ===========================================
# Run this on your Mac. It will:
#   1. Build a real (empty) .pkg installer
#   2. Print its SHA-256 hash
#   3. Give you upload instructions
#   4. Optionally test a public URL once uploaded
#
# Usage:
#   ./build_and_test.sh            # Build the dummy .pkg
#   ./build_and_test.sh --test <URL>   # Test a public URL

MODE=$1
URL=$2

# -----------------------------------------------
# MODE 1: Build the dummy .pkg (default)
# -----------------------------------------------
if [ -z "$MODE" ]; then

    BUILD_DIR="/tmp/mka_pkg_build"
    OUTPUT_PKG="/tmp/MKASetup_test.pkg"

    echo "========================================="
    echo "  Step 1: Building Dummy .pkg Installer"
    echo "========================================="
    echo ""

    # Create build directories
    mkdir -p "$BUILD_DIR/root"
    mkdir -p "$BUILD_DIR/scripts"

    # Create a do-nothing postinstall script
    cat > "$BUILD_DIR/scripts/postinstall" << 'EOF'
#!/bin/bash
echo "MKA test package installed successfully."
exit 0
EOF
    chmod +x "$BUILD_DIR/scripts/postinstall"

    # Build the .pkg
    pkgbuild \
        --root "$BUILD_DIR/root" \
        --scripts "$BUILD_DIR/scripts" \
        --identifier mka.onboarding.install \
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
    echo "  Step 2: Upload to a New Public GitHub Repo"
    echo "========================================="
    echo ""
    echo "  1. Go to https://github.com/new"
    echo "  2. Name it something like: mka-deployment-test"
    echo "  3. Set visibility to PUBLIC"
    echo "  4. Click 'Create repository'"
    echo "  5. Go to Releases → 'Create a new release'"
    echo "  6. Tag: v1.0-test"
    echo "  7. Upload: $OUTPUT_PKG as a release asset"
    echo "  8. Publish the release"
    echo ""
    echo "  Your URL will look like:"
    echo "  https://github.com/MK-Analytics/mka-deployment-test/releases/download/v1.0-test/MKASetup_test.pkg"
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
    echo "Step 4: Opening package installer..."
    open "$DOWNLOAD_PATH"
    echo "✅ Installer launched — you should see the macOS install prompt"

    echo ""
    echo "========================================="
    echo "  ✅ All checks passed!"
    echo "  Public URL works. Update ABM with your"
    echo "  real .pkg URL when ready."
    echo "========================================="

else
    echo "Usage:"
    echo "  ./build_and_test.sh               # Build dummy .pkg + upload instructions"
    echo "  ./build_and_test.sh --test <URL>  # Test a public URL"
fi