# Raster UI layout build results

Local uncommitted layout candidate; hardware acceptance is pending. The owner
accepted the preceding UI seed 61 with "looks good". Its finalized package at
`raster-playlist-ui-build-lrqmbnhv/hardware-test-seed61` remains the fallback.

## Functionality

- Center the visible playlist heading, including its default and scrolling window.
- Retain Phosphor playing-title scrolling: one character per ten output frames,
  with a 45-frame pause at each end. A full forward/back cycle is now verified;
  this behavior was already implemented in the accepted UI baseline.
- Render the progress bar and all three clocks in native 640×480 coordinates,
  scaled together into a centered fixed 4:3 area, independent of movie aspect.
- Keep subtitle layout, I-key lifecycle and 60 MHz playback clocks unchanged.

## Build and timing

Quartus Prime Lite 17.0.2, Cyclone V 5CSEBA6U23I7; isolated seeds 52/61/87,
HIGH packing, six fitter threads each. Timing sweeps run concurrently across
seeds and check all eight slow/fast 1100 mV corners (-40, 0, 85, 100 C).

| Seed | ALMs | RAM blocks | Setup | Hold | Recovery | Removal | Pulse width |
|---|---:|---:|---:|---:|---:|---:|---:|
| 52 | 33,058 | 545 | +0.274 | +0.060 | +2.748 | +0.189 | +0.925 |
| 61 | 33,111 | 545 | +0.277 | +0.098 | +3.884 | +0.212 | +0.925 |
| 87 | 33,108 | 545 | +0.253 | +0.114 | +2.871 | +0.242 | +0.925 |

Selected seed: **87**. Qualified seeds: 52, 87, 61.
Selected resource use: 60 DSPs and 3 PLLs.

All qualified seeds have nonnegative slack and zero TNS in every checked category.
The constraint audit matches the accepted baseline: 2473 no-clock HPS registers,
86 multiple-clock issues, one virtual clock, 14 missing input delays and 129
missing output delays; zero loops, latches or multicycle inconsistencies.
The seven inherited optional SPI/RESET constraint warnings are unchanged.

## Verification

- Metadata parsing and I-toggle lifecycle benches pass.
- Centered heading and row glyph pixels pass at 640×480, 1280×720 and 1920×1080.
- Full playing-title scroll cycle checks both pauses, return, fixed track number,
  stationary neighboring rows and reset after a track change/hide.
- Every rendered progress pixel matches nearest-neighbor scaling of the native
  640×480 scene at 320×240, 640×480, 1280×720, 1920×1080 and 1280×1024.
- Sync/DE alignment and hidden playlist pass-through checks pass.
- The earlier accepted playlist controller/reader/subtitle coverage is documented
  in the preceding UI report; this layout change does not modify those sources.

## Provenance

RBF: `/run/media/vash/GIT/raster-playlist-ui-build-cqg4t2pf/hardware-test-seed87/Raster_20260919.rbf`
SHA-256: `36f0b8929cf4cde9a7a642d6f5940037ad0bea3071351b64c273fc22d70fc50b`
Build root: `/run/media/vash/GIT/raster-playlist-ui-build-cqg4t2pf`

FPGA source hashes were checked against the frozen build snapshot. Documentation
and tests were finalized after compilation. Constrained timing does not cover
all inherited external-I/O paths; no agent-run hardware playback is claimed.
Nothing was committed, pushed or deployed.
