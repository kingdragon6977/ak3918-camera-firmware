#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
M4="$ROOT/mtds/extracted/mtd4-rootfs"
M5="$ROOT/mtds/extracted/mtd5-usrfs"
OUT="$ROOT/build"
STAGE="$OUT/stage"
PACKAGE="$OUT/update-package"

M4_LIMIT=$((0x100000))
M5_LIMIT=$((0x480000))

command -v mksquashfs >/dev/null 2>&1 || {
    echo "error: mksquashfs not found (install squashfs-tools)" >&2
    exit 1
}
command -v arm-anykav200-linux-uclibcgnueabi-gcc >/dev/null 2>&1 || {
    echo "error: Anyka cross compiler not in PATH" >&2
    exit 1
}
command -v patchelf >/dev/null 2>&1 || {
    echo "error: patchelf not found" >&2
    exit 1
}

echo "[1/5] Building volume-8 Anyka audio helper"
make -C "$ROOT" -f tools/Makefile.audio-gain clean
make -C "$ROOT" -f tools/Makefile.audio-gain VOLUME=8

echo "[2/5] Generating verified binary patches"
python3 "$ROOT/tools/patch_camera_binaries.py"

rm -rf "$STAGE"
mkdir -p "$STAGE/mtd4" "$STAGE/mtd5"
cp -a "$M4"/. "$STAGE/mtd4/"
cp -a "$M5"/. "$STAGE/mtd5/"

echo "[3/5] Integrating hardware-tested RTSP/audio binaries"
install -m 0755 "$ROOT/analysis/rtsp-flip00" "$STAGE/mtd5/bin/rtsp"
install -m 0755 "$ROOT/analysis/libapp_rtsp-aec0-nr1-agc0-vol8.so" "$STAGE/mtd5/lib/libapp_rtsp.so"
install -m 0755 "$ROOT/tools/libak_audio_gain.so" "$STAGE/mtd5/lib/libak_audio_gain.so"
# Load the gain helper as a normal dependency; avoid global LD_PRELOAD.
patchelf --add-needed libak_audio_gain.so "$STAGE/mtd5/lib/libapp_rtsp.so"

echo "[4/5] Building SquashFS 4.x images"
rm -f "$OUT/mtd4-rootfs.squashfs" "$OUT/mtd5-usrfs.squashfs"
mksquashfs "$STAGE/mtd4" "$OUT/mtd4-rootfs.squashfs" -noappend -all-root -comp xz -b 131072
mksquashfs "$STAGE/mtd5" "$OUT/mtd5-usrfs.squashfs" -noappend -all-root -comp xz -b 131072

check_size()
{
    FILE="$1"
    LIMIT="$2"
    SIZE=$(wc -c < "$FILE")
    echo "$FILE: $SIZE / $LIMIT bytes"
    if [ "$SIZE" -gt "$LIMIT" ]; then
        echo "error: image exceeds flash partition by $((SIZE - LIMIT)) bytes" >&2
        exit 1
    fi
}

echo "[5/6] Checking partition limits and hashes"
check_size "$OUT/mtd4-rootfs.squashfs" "$M4_LIMIT"
check_size "$OUT/mtd5-usrfs.squashfs" "$M5_LIMIT"
sha256sum "$OUT/mtd4-rootfs.squashfs" "$OUT/mtd5-usrfs.squashfs"

echo "[6/6] Building update.sh-compatible update.tar"
rm -rf "$PACKAGE"
mkdir -p "$PACKAGE"
cp "$OUT/mtd4-rootfs.squashfs" "$PACKAGE/root.sqsh4"
cp "$OUT/mtd5-usrfs.squashfs" "$PACKAGE/usr.sqsh4"

# TF update.sh rejects an equal fw_version, so use an explicit package
# version rather than silently copying /usr/fw_version.
FW_VERSION="${FW_VERSION:-6.0.05.10_202301061607-custom1}"
printf '%s\n' "$FW_VERSION" > "$PACKAGE/fw_version"

(
    cd "$PACKAGE"
    md5sum root.sqsh4 > root.sqsh4.md5
    md5sum usr.sqsh4 > usr.sqsh4.md5
    tar -cvf "$OUT/update.tar" \
        fw_version \
        root.sqsh4 root.sqsh4.md5 \
        usr.sqsh4 usr.sqsh4.md5
)

echo
echo "Updater package contents:"
tar -tvf "$OUT/update.tar"
echo
sha256sum "$OUT/update.tar"

echo
echo "Build complete:"
echo "  $OUT/mtd4-rootfs.squashfs"
echo "  $OUT/mtd5-usrfs.squashfs"
echo "  $OUT/update.tar"
