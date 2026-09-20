# Build qualification

The living record of Raster's builds: what was built, how it closed timing, what
was accepted on hardware, and where the artifacts came from. It replaces the
separate per-build reports written during the movie-only cleanup and the playlist
work (their content is carried here; git history keeps the originals). The build
procedure itself is in [BUILD.md](BUILD.md).

## Summary

| # | Date | Build | Selected seed | RBF SHA-256 | Hardware status |
|---|---|---|---:|---|---|
| 0 | 2026-09-15 | v0.9.5 combined player (before cleanup), reference only | 61 | `7ca93453…93fc` | Accepted by the owner (published release) |
| 1 | 2026-09-19 | Movie-only cleanup | 61 | `d3f9b369…b259` | Accepted: owner reported "everything passes" |
| 2 | 2026-09-19 | TAR/M3U playlists and linked SRTs | 87 | `916c647e…67df6` | Accepted: owner reported "everything works" |
| 3 | 2026-09-19 | Playlist panel UI | 61 | `01b8a7ca…36417` | Accepted: owner said "looks good" |
| 4 | 2026-09-19 | UI layout: centered heading, fixed 4:3 transport | 87 | `36f0b892…c50b` | Pending when recorded; superseded by 5 |
| 5 | 2026-09-20 | **Current:** no track numbers, A-key aspect switch, `Raster` project and source names | **52** | `e8fbebe8…bf4dfb` | **Accepted** (see below) |

Accepted builds share one limitation: timing was closed for the constrained paths
only (see [Timing coverage](#timing-coverage-and-limits)). No agent-run hardware
playback is claimed anywhere in this record; every hardware statement is the
owner's report.

## Current build (5)

Quartus Prime Lite 17.0.2 Build 602, Cyclone V `5CSEBA6U23I7`, project revision
`Raster` (top-level entity `sys_top`), HIGH ALM register packing, six fitter
threads, `SEED 52` pinned in `Raster.qsf`. Clock and decoder settings are
unchanged from the accepted baseline.

All three seeds compiled. Worst slack in ns across the eight corners (slow and
fast 1100 mV at -40, 0, 85 and 100 C):

| Seed | ALMs | RAM blocks | Setup | Hold | Recovery | Removal | Pulse width | Result |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| **52** | 32,930 | 545 | +0.335 | +0.109 | +3.912 | +0.213 | +0.925 | Pass, zero TNS |
| 61 | 32,962 | 545 | **-0.199** | +0.108 | +3.236 | +0.221 | +0.925 | **Fails setup** (TNS -1.832) |
| 87 | 32,888 | 545 | +0.064 | +0.106 | +3.459 | +0.210 | +0.925 | Pass, zero TNS |

Seed 52 is pinned: best setup and the best minimum margin across the five
categories (+0.109 ns, against +0.064 ns for seed 87). Seed 61, the seed of the
earlier accepted builds, no longer closes timing on this source. Do not use it.
Resources for seed 52: 32,930 of 41,910 ALMs (79%), 545 of 553 RAM blocks (99%),
60 of 112 DSP blocks, 3 of 6 PLLs.

**Reproducibility.** A fresh `git clone` at commit `89a9992`, built with
`tools/build_seeds.sh` for seed 52 (no manual edits), reproduced identical
resources and timing and a byte-identical bitstream: 4,434,780 bytes, SHA-256
`e8fbebe8397e581eddbdd4d0a64823e84b887cfdd0f895401a576f2808bf4dfb`. The same bytes
came out of the source before and after the project rename (`MediaPlayer.*` to
`Raster.*`) and the source-file rename (`MediaPlayer*.sv/.svh` to `Raster*`), so
neither rename changes the design. The build stamp inside the bitstream is the
build date (`260920`); a build on another day differs in those bytes only.

**Hardware.** The owner reported on 2026-09-19 that the fix worked on hardware and
on 2026-09-20 asked for the seed 52 build to be recorded as accepted. The file
tested on hardware was an earlier build of the same seed 52 design and is no longer
on disk; the artifact above was built afterwards and matches it in resources and
timing, but was not compared byte for byte with the tested file.

## Earlier builds

Worst slack in ns across the eight corners. Every listed seed closed all five
categories with zero TNS unless marked.

**1. Movie-only cleanup** (base `ebaea21`). Removed standalone FLAC and CUESHEET
playback, music PCM and time interfaces, the CD clock and HDMI handoff stack, all
three visualizers and their FFT tables, the FLAC tools, and unused template and
audio-test source. The MPEG-2 and MP2 decoders, A/V timing, seeking, subtitles and
transport UI are unchanged. Synthesis passed with zero errors and 3,923 warnings
(3,814 of them width truncations). The build compiled with 3,943 warnings and the
timing run reported seven warnings per seed.

| Seed | Setup | Hold | Recovery | Removal | Pulse width |
|---|---:|---:|---:|---:|---:|
| 52 | +0.499 | +0.090 | +3.521 | +0.204 | +0.925 |
| **61** | +0.485 | +0.116 | +3.617 | +0.157 | +0.925 |
| 87 | +0.113 | +0.118 | +2.988 | +0.209 | +0.925 |

Seed 61 had the best minimum margin (+0.116 ns).

**2. TAR/M3U playlists and linked SRTs.**

| Seed | ALMs | RAM blocks | Setup | Hold | Recovery | Removal | Pulse width |
|---|---:|---:|---:|---:|---:|---:|---:|
| 52 | 31,520 | 530 | +0.288 | +0.087 | +3.254 | +0.198 | +0.925 |
| 61 | 31,572 | 530 | +0.127 | +0.093 | +3.377 | +0.109 | +0.925 |
| **87** | 31,576 | 530 | +0.503 | +0.107 | +3.056 | +0.184 | +0.925 |

Playlists added 16 RAM blocks over build 1. The owner's acceptance covered M3U
ordering, N/P navigation and wrapping, natural EOF advance and looping, movie
audio, pause/resume and seeking, automatic SRT association, persistent visibility
and clearing of absent subtitles, manual SRT override, reset to the first entry,
and loading another TAR or a standalone MPG. It does not establish real-time
480p59.94/60 decoding; the stress-file throughput and A/V drift observed earlier
remain separate limitations.

**3. Playlist panel UI.** The I key toggles a six-row playlist panel with M3U
titles, current-movie highlighting, N/P following and scrolling titles.

| Seed | ALMs | RAM blocks | Setup | Hold | Recovery | Removal | Pulse width |
|---|---:|---:|---:|---:|---:|---:|---:|
| 52 | 32,784 | 545 | **-0.041** | +0.098 | +3.695 | +0.218 | +0.925 |
| **61** | 32,772 | 545 | +0.186 | +0.116 | +2.796 | +0.175 | +0.925 |
| 87 | 32,812 | 545 | +0.483 | +0.066 | +2.898 | +0.171 | +0.925 |

Seed 52 failed setup; 61 and 87 qualified.

**4. UI layout.** Centered playlist heading, and the progress bar and clocks
rendered in native 640×480 coordinates and scaled together into a centered 4:3
area regardless of movie aspect.

| Seed | ALMs | RAM blocks | Setup | Hold | Recovery | Removal | Pulse width |
|---|---:|---:|---:|---:|---:|---:|---:|
| 52 | 33,058 | 545 | +0.274 | +0.060 | +2.748 | +0.189 | +0.925 |
| 61 | 33,111 | 545 | +0.277 | +0.098 | +3.884 | +0.212 | +0.925 |
| **87** | 33,108 | 545 | +0.253 | +0.114 | +2.871 | +0.242 | +0.925 |

**0. Reference: v0.9.5 combined player.** Published figures, not a fresh rebuild:
35,817 ALMs (85%), 51,622 registers, 4,158,522 block-memory bits, 546 RAM blocks
(99%), 75 DSP blocks, 4 PLLs; zero TNS.

| Corner | Setup | Hold | Recovery | Removal | Pulse width |
|---|---:|---:|---:|---:|---:|
| Slow 1100 mV 100 C | +0.236 | +0.237 | +3.468 | +0.561 | +0.925 |
| Slow 1100 mV -40 C | +0.127 | +0.166 | +3.574 | +0.482 | +0.925 |
| Fast 1100 mV 100 C | +2.926 | +0.133 | +4.848 | +0.262 | +0.925 |
| Fast 1100 mV -40 C | +3.526 | +0.045 | +5.105 | +0.179 | +0.925 |

## Resource history

| Build | ALMs | Registers | RAM blocks | DSP | PLLs |
|---|---:|---:|---:|---:|---:|
| 0 v0.9.5 combined player | 35,817 (85%) | 51,622 | 546 | 75 | 4 |
| 1 movie-only (seed 61) | 30,299 (72%) | 43,155 | 514 | 60 | 3 |
| 2 playlists (seed 87) | 31,576 (75%) | | 530 | 60 | 3 |
| 3 playlist UI (seed 61) | 32,772 | | 545 | 60 | 3 |
| 4 UI layout (seed 87) | 33,108 | | 545 | 60 | 3 |
| 5 current (seed 52) | 32,930 (79%) | | 545 | 60 | 3 |

The movie-only cleanup cut block-memory use from 4,158,522 to 3,872,709 bits and
raised free RAM blocks from 7 to 39; later features have taken most of that back.
Block RAM, not logic, is the binding resource: 545 of 553 blocks leaves eight
free. Budget any new RAM against that ceiling first.

## Timing coverage and limits

Passing summaries establish closure for the constrained paths, not complete
board-level interface sign-off. The audit is unchanged since build 1:

- `report_ucp`: zero illegal or unconstrained clocks, four unconstrained input
  ports and 49 unconstrained output ports (HDMI audio and video outputs, I2C).
- `check_timing`: 2,473 no-clock nodes confined to HPS and interface prefixes
  (`sysmem_lite:sysmem`, `h2f_gp`, `hdmi_i2c`), 86 multiple-clock entries, one
  unused virtual clock, 14 missing input-delay and 129 missing output-delay
  entries; zero loops, latches, generated-clock issues or multicycle-consistency
  issues.
- Seven timing warnings per run: unmatched optional ALSA SPI clock and group
  filters in `sys/sys_top.sdc`, and unmatched top-level RESET exceptions in
  `Raster.sdc`. These predate the cleanup; no timing exceptions were added to
  obtain any result.

External-interface behavior therefore stays part of hardware acceptance.

## Verification during development

Builds 1 to 4 were checked with simulation benches and browser tests that are not
part of this repository. In summary: the playlist controller with the real SD
reader (M3U order independent of TAR layout, linked and absent SRTs, N/P, OSD key
suppression, EOF and loop, reopen, bounded header scanning, 255 entries, malformed
and ambiguous archives); two readers with the SD owner (member-relative offsets,
odd byte lengths, backpressure, cancellation); the subtitle parser and controller;
M3U metadata parsing (CRLF/LF/CR, filename fallback, long text, all 255 entries);
I-key lifecycle; exact RTL pixel renders of the panel at 640×480, 1280×720 and
1920×1080; every progress-bar pixel against nearest-neighbor scaling at five
output sizes; and the Chrome/WASM builder (exact payload round-trips, SRT pairing,
limits, real ffmpeg.wasm conversions verified with ffprobe). Build 5 was checked
by the A-key toggle bench, the playlist scroll and pixel benches, and the
from-clone reproduction above. Tests used synthetic fixtures.

## Artifacts and provenance

Local paths, on the build machine only (not in the repository):

| Build | RBF |
|---|---|
| 0 | `MiSTer-Phosphor_v0.9.5.zip`, member `MediaPlayer_20260915.rbf` (4,520,032 bytes; archive SHA-256 `da1c8766d79b8184b467213e6e125a1a45c41c28ad3d5c2f9e98b2396fae02fa`; source `1720960`, seed 61) |
| 1 | `raster-movie-build-up5c4hr5/hardware-test-seed61/Raster_20260919.rbf` (4,319,788 bytes; SHA-256 `d3f9b369a8ceb4b4c830a8f781512f0b43817d13fb1f59502a7b7a1666d3b259`) |
| 2 | `raster-playlist-build-1taiwa79/hardware-test-seed87/Raster_20260919.rbf` (4,396,664 bytes; SHA-256 `916c647edaa8e9dade9f52f3cdf469b724d330437b36982a5ef78797d3c67df6`) |
| 3 | `raster-playlist-ui-build-lrqmbnhv/hardware-test-seed61/Raster_20260919.rbf` (SHA-256 `01b8a7ca6c633f8a96d4735507b8f4b1806f12bdf05c2fa2fd51b6b087e36417`) |
| 4 | `raster-playlist-ui-build-cqg4t2pf/hardware-test-seed87/Raster_20260919.rbf` (SHA-256 `36f0b8929cf4cde9a7a642d6f5940037ad0bea3071351b64c273fc22d70fc50b`) |
| 5 | `Raster.rbf` from `tools/build_seeds.sh` (4,434,780 bytes; SHA-256 `e8fbebe8397e581eddbdd4d0a64823e84b887cfdd0f895401a576f2808bf4dfb`) |

Each build root also kept its source snapshot, manifest and per-seed timing
reports. Release copies are named `Raster_YYYYMMDD.rbf`.

## Adding an entry

After a full three-seed build and eight-corner sweep (see [BUILD.md](BUILD.md)):
add a row to the summary table and a section with the seed table (ALMs, RAM
blocks, the five slacks, TNS), the resources of the selected seed, the artifact's
size and SHA-256, and the source commit. Record hardware status only as the
owner reports it, with the date. Keep the coverage limits above unless they
change.
