#!/usr/bin/env python3
"""Generate reproducible AK3918 RTSP test binaries from the extracted originals.

This script does not modify the source binaries in place.
"""
from pathlib import Path
import hashlib
import struct

ROOT = Path(__file__).resolve().parents[1]
RTSP = ROOT / "mtds/extracted/mtd5-usrfs/bin/rtsp"
LIBAPP = ROOT / "lib/libapp_rtsp.so"
OUT = ROOT / "analysis"

ARM_MOV_R1_1 = bytes.fromhex("01 10 a0 e3")
ARM_MOV_R1_0 = bytes.fromhex("00 10 a0 e3")
ARM_MOV_R2_1 = bytes.fromhex("01 20 a0 e3")
ARM_MOV_R2_0 = bytes.fromhex("00 20 a0 e3")
ARM_MOV_R1_5 = bytes.fromhex("05 10 a0 e3")

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

def arm_bl(src_vma, dst_vma):
    """Encode ARM-state BL from src_vma to dst_vma."""
    delta = dst_vma - (src_vma + 8)
    if delta % 4:
        raise ValueError("unaligned ARM branch target")
    imm24 = (delta >> 2) & 0x00ffffff
    return struct.pack("<I", 0xeb000000 | imm24)

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
        "08 00 1b e5 "
        "01 10 a0 e3 "
        "42 ef ff eb "
        "08 00 1b e5 "
        "01 10 a0 e3 "
        "fc ef ff eb"
    )

    b = bytearray(LIBAPP.read_bytes())
    base = patch_exact(b, seq, seq, "audio init sequence")

    # AEC off; leave combined NR/AGC on.
    assert b[base+16:base+20] == ARM_MOV_R1_1
    b[base+16:base+20] = ARM_MOV_R1_0
    p_aec = OUT / "libapp_rtsp-aec0.so"
    p_aec.write_bytes(b)

    # AEC off + combined NR/AGC off (diagnostic only; known to sound worse).
    b2 = bytearray(b)
    assert b2[base+4:base+8] == ARM_MOV_R1_1
    b2[base+4:base+8] = ARM_MOV_R1_0
    p_raw = OUT / "libapp_rtsp-aec0-nragc0.so"
    p_raw.write_bytes(b2)

    # AEC off + NR on + AGC off:
    # libapp_rtsp imports ak_ai_set_nr_agc, but libplat_ai also exports
    # ak_ai_set_nr.  The shorter symbol name fits in-place in .dynstr,
    # so the existing relocation/PLT entry can resolve to ak_ai_set_nr
    # without changing ELF layout.
    b3 = bytearray(b)
    old_name = b"ak_ai_set_nr_agc\x00"
    short_name = b"ak_ai_set_nr\x00"
    new_name = short_name + (b"\x00" * (len(old_name) - len(short_name)))
    patch_exact(b3, old_name, new_name, "dynamic symbol ak_ai_set_nr_agc")
    p_nr = OUT / "libapp_rtsp-aec0-nr1-agc0.so"
    p_nr.write_bytes(b3)

    # Safe fixed-volume helper patch while preserving AEC=0, NR=1, AGC off
    # and the original ak_ai_clear_frame_buffer() call.  Redirect only the
    # ak_ai_set_source dynsym to the short helper symbol ak_ai_src_gain.
    # Run with LD_PRELOAD=/tmp/libak_audio_gain.so so the helper performs:
    #     ak_ai_set_source(ai, source)
    #     ak_ai_set_volume(ai, AK_FIXED_AI_VOLUME)
    # This leaves the RTSP instruction stream and clear-frame-buffer PLT
    # entry untouched.
    b4 = bytearray(b3)
    old_source = b"ak_ai_set_source" + bytes([0])
    helper_name = b"ak_ai_src_gain" + bytes([0])
    helper_padded = helper_name + (bytes([0]) * (len(old_source) - len(helper_name)))
    patch_exact(b4, old_source, helper_padded,
                "dynamic symbol ak_ai_set_source")
    p_nr_v5 = OUT / "libapp_rtsp-aec0-nr1-agc0-vol5.so"
    p_nr_v5.write_bytes(b4)

    for q in (RTSP, OUT/"rtsp-flip00", LIBAPP, p_aec, p_raw, p_nr, p_nr_v5):
        print(f"{sha256(q)}  {q.relative_to(ROOT)}")

if __name__ == "__main__":
    build()
