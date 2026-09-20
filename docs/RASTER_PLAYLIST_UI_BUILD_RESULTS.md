# Raster playlist UI build results

Local uncommitted candidate. The owner accepted this UI with "looks good" on
2026-09-19. This seed 61 is the accepted UI baseline for subsequent layout work. Decoder/audio/PLL
sources are unchanged; the decoder remains at 60 MHz. Nothing was pushed.

## Functionality

I toggles a six-row TAR movie playlist panel. M3U playlist/movie titles, current
movie highlighting, N/P and automatic-transition following, and scrolling titles
are rendered over HDMI video. Visibility persists across entries and clears on
a new mount/reset; standalone MPG has no playlist panel. Subtitles and transport
remain above the panel. Text uses 31 printable ASCII bytes per name.

## Build and timing

Quartus Prime Lite 17.0.2, Cyclone V 5CSEBA6U23I7; HIGH packing and six fitter
threads per seed. Dedicated timing sweeps run concurrently across seeds.
All eight slow/fast 1100 mV corners (-40, 0, 85, 100 C) were
examined. The table shows minimum slack in ns across corners.

| Seed | ALMs | RAM blocks | Setup | Hold | Recovery | Removal | Pulse width |
|---|---:|---:|---:|---:|---:|---:|---:|
| 52 | 32,784 | 545 | -0.041 | +0.098 | +3.695 | +0.218 | +0.925 |
| 61 | 32,772 | 545 | +0.186 | +0.116 | +2.796 | +0.175 | +0.925 |
| 87 | 32,812 | 545 | +0.483 | +0.066 | +2.898 | +0.171 | +0.925 |

Selected seed: **61**. Seeds passing every constrained category with zero TNS: 61, 87.
Selected resource use: 60 DSP blocks and 3 PLLs.

## Verification

- Actual controller/reader: order, navigation, EOF, loop, linked subtitles,
  malformed input and browser-builder TAR input.
- Metadata: CRLF/LF/CR, mixed plain/extended M3U, filename fallback, long text,
  all 255 entries and reopen.
- I key: typematic, OSD suppression, entry transition, new file and standalone.
- Actual RTL pixel render: 640x480, 1280x720, 1920x1080; exact title glyphs,
  selected/unused rows, video timing and unchanged pixels with panel hidden.
- Existing member-reader and linked-subtitle integration benches pass.

## Provenance

RBF: `/run/media/vash/GIT/raster-playlist-ui-build-lrqmbnhv/hardware-test-seed61/Raster_20260919.rbf`
SHA-256: `01b8a7ca6c633f8a96d4735507b8f4b1806f12bdf05c2fa2fd51b6b087e36417`
Build root: `/run/media/vash/GIT/raster-playlist-ui-build-lrqmbnhv`

The source archive and manifest retain the exact HDL/project inputs. Final
documentation and test updates were included after compilation. The inherited
external-I/O constraint limitations still apply; passing constrained timing
is not full board-I/O sign-off. No agent-run hardware playback is claimed.
