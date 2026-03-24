#!/bin/bash

# Test script to verify a URL is publicly accessible, download the file, and open it
# Usage: ./test_download.sh

URL="https://github.com/MK-Analytics/MKA_Knowledge_Base/releases/download/v1.0/MKASetup.pkg"
EXPECTED_HASH="fe5083d6995906df058ea49d3a5bc8c2979787487796303de205df0d77926c8d"
DOWNLOAD_PATH="/tmp/MKASetup.pkg"

echo "========================================="
echo "  MKA Package Deployment Test"
echo "========================================="
echo ""

# Step 1: Check URL is reachable
echo "Step 1: Checking URL accessibility..."
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" "$URL")

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "✅ URL is publicly accessible (HTTP $HTTP_STATUS)"
elif [ "$HTTP_STATUS" -eq 404 ]; then
    echo "❌ URL returned 404 - repository is likely private or file doesn't exist"
    echo "   Fix: Host the .pkg file at a publicly accessible URL"
    exit 1
else
    echo "❌ Unexpected HTTP status: $HTTP_STATUS"
    exit 1
fi

echo ""

# Step 2: Download the file
echo "Step 2: Downloading package to $DOWNLOAD_PATH..."
curl -L --progress-bar "$URL" -o "$DOWNLOAD_PATH"

if [ $? -eq 0 ]; then
    echo "✅ Download complete"
else
    echo "❌ Download failed"
    exit 1
fi

echo ""

# Step 3: Verify SHA-256 hash
echo "Step 3: Verifying SHA-256 hash..."
ACTUAL_HASH=$(shasum -a 256 "$DOWNLOAD_PATH" | awk '{print $1}')

echo "   Expected: $EXPECTED_HASH"
echo "   Actual:   $ACTUAL_HASH"

if [ "$ACTUAL_HASH" == "$EXPECTED_HASH" ]; then
    echo "✅ Hash matches - file integrity confirmed"
else
    echo "⚠️  Hash mismatch - file may have changed since ABM was configured"
    echo "   You will need to update the SHA-256 hash in ABM"
fi

echo ""

# Step 4: Open the package
echo "Step 4: Opening package installer..."
open "$DOWNLOAD_PATH"

if [ $? -eq 0 ]; then
    echo "✅ Package opened successfully"
else
    echo "❌ Failed to open package"
    exit 1
fi

echo ""
echo "========================================="
echo "  Test Complete"
echo "========================================="