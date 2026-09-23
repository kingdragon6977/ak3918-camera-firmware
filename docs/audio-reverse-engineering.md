# AK3918 RTSP audio reverse-engineering notes

## Confirmed runtime baseline

The best microphone result tested so far is:

- AEC disabled
- NR/AGC enabled
- MIC source retained

Disabling both AEC and NR/AGC caused rapid audio breakup/static-like clipping, so that combination is retained only as a diagnostic variant.

## RTSP audio initialization

`libapp_rtsp.so` initializes audio approximately as:

```text
ak_ai_open(8000 Hz, 16-bit, mono)
ak_ai_set_nr_agc(ai, 1)
ak_ai_set_aec(ai, 1)
ak_ai_set_source(ai, 1)   # runtime log identifies 1 as MIC
ak_ai_clear_frame_buffer(ai)
ak_ai_set_frame_interval(ai, 40)
```

The tested AEC-off patch changes only the AEC argument from 1 to 0.

## ak_ai_set_volume

`libplat_ai.so` exports `ak_ai_set_volume` at 0x2ff8 and accepts API values 0..12.

For values 1..8, the internal routine at 0x180c (`pcm_adc_set_volume`, identified by rodata) sends `volume - 1` to ADC ioctl `0x40045030`.

| API volume | ADC ioctl gain |
|---:|---:|
| 1 | 0 |
| 2 | 1 |
| 3 | 2 |
| 4 | 3 |
| 5 | 4 |
| 6 | 5 |
| 7 | 6 |
| 8 | 7 |

Values 9..12 first force the normal ADC volume path to 8, then configure an additional `_SD_Filter` / ASLC stage. These values should not be treated as simple linear ADC gain.

`ak_ai_open` initializes each returned AI handle's field at offset +0x34 to 5:

```asm
2360: mov r2,#5
2368: str r2,[r5,#52]
```

A successful `pcm_adc_set_volume` stores the requested API value to the same handle offset:

```asm
1850: ldrge r3,[sp,#12]
1858: strge r3,[r4,#52]
```

This strongly identifies handle +0x34 as the API volume state. However, merely changing the initializer at 0x2360 is **not sufficient evidence that hardware gain changes**, because the only calls to the actual ADC-volume routine at 0x180c are from `ak_ai_set_volume`. A proper fixed-gain experiment must actually invoke `ak_ai_set_volume(handle, N)` or issue the equivalent ADC ioctl on the active handle.

## Reproducible patches

Run:

```bash
python3 tools/patch_camera_binaries.py
```

It generates/verifies:

- `analysis/rtsp-flip00`: video flip/mirror flags 1,1 -> 0,0; hardware-tested desired 180-degree orientation.
- `analysis/libapp_rtsp-aec0.so`: AEC off, NR/AGC on; currently best tested audio configuration.
- `analysis/libapp_rtsp-aec0-nragc0.so`: AEC off, NR/AGC off; diagnostic variant that sounded substantially worse.

The patcher validates the expected instruction sequences before writing outputs so it fails rather than silently patching an unexpected binary.
