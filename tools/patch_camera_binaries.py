#!/usr/bin/env python3
"""Generate reproducible AK3918 RTSP test binaries from the extracted originals.

This script does not modify the source binaries in place.
"""
from pathlib import Path
import argparse
import hashlib

ROOT = Path(__file__).resolve().parents[1]
RTSP = ROOT / "mtds/extracted/mtd5-usrfs/bin/rtsp"
LIBAPP = ROOT / "lib/libapp_rtsp.so"
OUT = ROOT / "analysis"

ARM_MOV_R1_1 = bytes.fromhex("01 10 a0 e3")
ARM_MOV_R1_0 = bytes.fromhex("00 10 a0 e3")
ARM_MOV_R2_1 = bytes.fromhex("01 20 a0 e3")
ARM_MOV_R2_0 = bytes.fromhex("00 20 a0 e3")

def sha256(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def patch_exact(data, old, new, label):
    hits = []
    pos = 0
    while True:
        i = data.find(old, pos)
        if i < 0:
            break
        hits.append(i)
        pos = i + 1
    if len(hits) != 1:
        raise RuntimeError(f"{label}: expected one match, found {len(hits)}: {[hex(x) for x in hits]}")
    i = hits[0]
    data[i:i+len(old)] = new
    return i

def build():
    OUT.mkdir(exist_ok=True)

    # Video orientation: stock RTSP calls ak_vi_set_flip_mirror(handle, 1, 1)
    # at VMA 0x9adc/0x9ae0. For this ELF, file offsets are 0x1adc/0x1ae0.
    b = bytearray(RTSP.read_bytes())
    assert b[0x1adc:0x1ae0] == ARM_MOV_R1_1
    assert b[0x1ae0:0x1ae4] == ARM_MOV_R2_1
    b[0x1adc:0x1ae0] = ARM_MOV_R1_0
    b[0x1ae0:0x1ae4] = ARM_MOV_R2_0
    p = OUT / "rtsp-flip00"
    p.write_bytes(b)
    p.chmod(0o755)

    # Audio init sequence: NR/AGC=1, AEC=1, source=MIC.
    seq = bytes.fromhex(
        "08 00 1b e5 "  # ldr r0,[fp,#-8]
        "01 10 a0 e3 "  # mov r1,#1 ; NR/AGC
        "42 ef ff eb "  # bl ak_ai_set_nr_agc@plt
        "08 00 1b e5 "  # ldr r0,[fp,#-8]
        "01 10 a0 e3 "  # mov r1,#1 ; AEC
        "fc ef ff eb"   # bl ak_ai_set_aec@plt
    )

    b = bytearray(LIBAPP.read_bytes())
    base = patch_exact(b, seq, seq, "audio init sequence")
    assert b[base+16:base+20] == ARM_MOV_R1_1
    b[base+16:base+20] = ARM_MOV_R1_0
    p_aec = OUT / "libapp_rtsp-aec0.so"
    p_aec.write_bytes(b)

    b2 = bytearray(b)
    assert b2[base+4:base+8] == ARM_MOV_R1_1
    b2[base+4:base+8] = ARM_MOV_R1_0
    p_raw = OUT / "libapp_rtsp-aec0-nragc0.so"
    p_raw.write_bytes(b2)

    for p in (RTSP, OUT/"rtsp-flip00", LIBAPP, p_aec, p_raw):
        print(f"{sha256(p)}  {p.relative_to(ROOT)}")

if __name__ == "__main__":
    build()
