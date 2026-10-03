# Full-resolution FPS and microphone build

Run `sh tools/build_squashfs.sh` with the Anyka cross compiler in PATH.
The output is `build/update.tar`; its version is custom2-fps25-gain8.

The RTSP main stream remains 1280x720 with the existing 25 FPS encoder.
The new video dependency disables exposure-driven FPS switching and calls
`ak_vi_set_fps(vi, 30)`. Existing logs show sensor switching between 15 and
30 FPS; the vendor library disassembly confirms the FPS API forwards its
integer argument to `isp_set_sensor_fps`. Orientation remains flip=0/mirror=0.
This is a firmware target, not a hardware-verified frame-rate result.

Audio retains the existing gain-8 helper: MIC source, AEC off, NR on,
AGC off, followed by an actual `ak_ai_set_volume(ai, 8)` call. Gain 8 is
already the highest normal ADC gain; 9..12 add nonlinear processing.
The previous build already included this audio setting.

Before flashing, preserve a recoverable original firmware backup. After
installing, measure delivered frames over at least 30 seconds in bright
and dim lighting; verify 1280x720 and 25 unique frames/second, rather than
trusting the advertised RTSP rate. Listen for clipping with nearby loud
speech and check distant speech sensitivity. Fixed high FPS shortens
exposure in dim light and may darken the image. No camera was flashed by
this build process.
