#!/usr/bin/env bash
set -euo pipefail

echo "=== AIOS ISO Builder ==="

# Use /workspace (mounted Docker volume) as the working directory.
# This ensures plenty of disk space for the chroot, squashfs, and ISO
# artifacts — the container overlay FS is often too small (~800 MB free).
WORKSPACE="/workspace"
mkdir -p "$WORKSPACE"

echo "Copying build config to workspace..."
rm -rf "$WORKSPACE/config" "$WORKSPACE/auto"
cp -r /build-config/config "$WORKSPACE/config"
cp -r /build-config/auto   "$WORKSPACE/auto"
chmod +x "$WORKSPACE/auto/config"
find "$WORKSPACE/config/hooks" -name '*.hook.chroot' -exec chmod +x {} +

cd "$WORKSPACE"

# Clean previous builds
lb clean --purge 2>/dev/null || true

echo "Configuring live-build..."
lb config

# Verify distribution (catch misconfiguration early)
if grep -q 'LB_DISTRIBUTION="trixie"' .build/config 2>/dev/null; then
    echo "  Distribution: trixie (OK)"
else
    echo "  WARNING: Could not verify distribution is trixie"
fi

# Verify that AIOS binaries are present in the chroot overlay.
BINDIR="config/includes.chroot/usr/local/bin"
EXPECTED_BINS="aios-agent aios-chat aios-dock aios-confirm"
MISSING=0
for bin in $EXPECTED_BINS; do
    if [ ! -f "${BINDIR}/${bin}" ]; then
        echo "ERROR: Missing binary: ${BINDIR}/${bin}"
        MISSING=1
    else
        echo "  Found: ${bin} ($(du -h "${BINDIR}/${bin}" | cut -f1))"
    fi
done
if [ "$MISSING" -eq 1 ]; then
    echo "FATAL: Run 'make build-linux install-binaries' before building the ISO."
    exit 1
fi

echo "Building ISO..."
lb build

# Copy ISO to the output volume
mkdir -p /output
ISO_FILE=$(ls "$WORKSPACE"/*.iso 2>/dev/null | head -1)
if [ -n "$ISO_FILE" ]; then
    cp -v "$ISO_FILE" /output/
    echo "=== Build complete ==="
    ls -lh /output/*.iso
else
    echo "FATAL: No ISO file produced. Check build logs above."
    exit 1
fi
