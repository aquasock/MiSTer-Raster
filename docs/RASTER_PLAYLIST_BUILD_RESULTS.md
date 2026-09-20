# Raster playlist build results

Local uncommitted candidate, 2026-09-19. The accepted movie-only baseline is
documented separately in [baseline results](RASTER_BUILD_RESULTS.md). This
candidate adds TAR/M3U movie playlists and linked SRTs. On 2026-09-19, the
owner confirmed that the hardware checklist works and accepted playlist seed 87.
No agent deployment, push or change to Phosphor was made.

## Build and timing

Quartus Prime Lite 17.0.2 Build 602; Cyclone V `5CSEBA6U23I7`; HIGH ALM
register packing; six fitter threads per seed. Clean isolated copies were
built for seeds 52, 61 and 87. Each full compile completed successfully.

The dedicated timing pass enumerated all eight available operating conditions:
slow/fast 1100 mV at -40, 0, 85 and 100 °C. The table gives minimum slack in ns
across all corners; all listed categories have zero total negative slack.

| Seed | ALMs | RAM blocks | Setup | Hold | Recovery | Removal | Pulse width |
|---|---:|---:|---:|---:|---:|---:|---:|
| 52 | 31,520 | 530 | +0.288 | +0.087 | +3.254 | +0.198 | +0.925 |
| 61 | 31,572 | 530 | +0.127 | +0.093 | +3.377 | +0.109 | +0.925 |
| 87 | 31,576 | 530 | +0.503 | +0.107 | +3.056 | +0.184 | +0.925 |

Seed **87** is selected for the best minimum margin across the five timing
categories. It uses 31,576/41,910 ALMs (75%), 530/553 RAM blocks
(96%), 60/112 DSP blocks and three PLLs. The playlist feature adds 16 RAM
blocks relative to the accepted 514-block movie-only baseline.

## Coverage limitations

These are constrained-path timing results, not complete board-I/O sign-off.
The inherited constraint audit still reports 2,473 no-clock HPS interface
registers, 86 multiple-clock entries, one virtual clock, 14 missing input
delays and 129 missing output delays, matching the baseline audit summary.
Optional SPI and RESET-related empty-collection warnings remain. The report
finds no latches, loops or multicycle-consistency issues. No constraints were
relaxed for playlists. Owner hardware acceptance is recorded below; it does not
expand the constrained timing coverage.

## Functional checks

- Controller plus actual SD reader: M3U order independent of TAR layout, linked
  and absent SRTs, standalone MPG, N/P, OSD key suppression, EOF/loop, reopen,
  bounded header scanning, 255 entries and malformed/ambiguous archive rejection.
- Two real readers and SD owner: member-relative offsets, odd byte lengths,
  shared TAR slot, manual SRT slot, backpressure, cancellation and trailing writes.
- Actual subtitle controller/parser: linked load, visibility toggle, persistent
  visibility across movies and clearing when the next movie has no SRT.
- Chrome from `file://`: WASM TAR generation/import, exact payload round-trips,
  automatic SRT pairing, reordering, limits, malformed input and mobile layout.
  Browser-produced archives also pass the production RTL simulation.
- Real ffmpeg.wasm conversions: 24/30 fps, 4:3/16:9, Standard/Maximum, MPEG-2
  720×480 YUV420P, optional MP2 48 kHz stereo 192 kbit/s; ffprobe verifies output.
  Direct Add to playlist preserves converted MPG and matching SRT bytes.
  Failure handling, cancellation/retry and converter mobile layout pass.

Tests generate synthetic fixtures; no agent-run hardware playback is claimed.

## Hardware acceptance

On 2026-09-19, after receiving the hardware checklist, the owner reported
"everything works". Playlist seed 87 is accepted for M3U ordering, N/P navigation
and wrapping, natural EOF advance and looping, movie audio, pause/resume and
seeking, automatic SRT association, persistent visibility and clearing absent
subtitles, manual SRT override, reset to the first entry and loading another TAR
or standalone MPG. This records the owner's confirmation; no per-file test log
or agent-run hardware test is claimed.

This acceptance covers playlist functionality. It does not establish real-time
480p59.94/60 decoding; the previously observed stress-file throughput and A/V
drift remain separate limitations. No decoder clock change was made.

## Candidate and provenance

- RBF: `/run/media/vash/GIT/raster-playlist-build-1taiwa79/hardware-test-seed87/Raster_20260919.rbf`
- Size: 4,396,664 bytes
- SHA-256: `916c647edaa8e9dade9f52f3cdf469b724d330437b36982a5ef78797d3c67df6`
- Build/report root: `/run/media/vash/GIT/raster-playlist-build-1taiwa79`
- `source/` and `source_manifest.json` retain the source snapshot and checksums.
  Documentation/tests/browser additions were updated after compilation; all
  HDL, project and constraint inputs were compared to the build snapshot.
- `working-tree.patch` records tracked changes; the full source archive also
  includes new untracked source. The base commit is recorded in `provenance.json`.
- The handoff directory contains the RBF, source archive, builder ZIP, checksum
  manifest, build results and hardware-check instructions.
