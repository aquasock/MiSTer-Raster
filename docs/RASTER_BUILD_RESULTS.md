# Raster movie-only build qualification

2026-09-19. Local uncommitted working tree based on `ebaea217a4e7a719610ef2a8ac79a4681579dcfa`. No commits, pushes, releases or hardware deployment were performed.

## Build and timing results

Quartus Prime Lite 17.0.2 Build 602, Cyclone V `5CSEBA6U23I7`, HIGH packing, six processors per build. All three clean builds produced RBFs with zero errors (3,943 compile warnings each). Dedicated TimeQuest runs completed with zero errors and seven warnings each.

All five constrained timing categories pass at all eight available conditions: slow and fast 1100 mV at -40, 0, 85 and 100 C. Every summary has zero total negative slack. Values below are worst slack in ns across those eight corners.

| Seed | Setup | Hold | Recovery | Removal | Min pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| 52 | +0.499 | +0.090 | +3.521 | +0.204 | +0.925 |
| 61 | +0.485 | +0.116 | +3.617 | +0.157 | +0.925 |
| 87 | +0.113 | +0.118 | +2.988 | +0.209 | +0.925 |

Selected seed **61** maximizes the minimum slack across the five categories: +0.116 ns versus +0.090 ns for seed 52 and +0.113 ns for seed 87. Seed 52 has slightly better setup, but less hold margin.

## Resource comparison

| Resource | Published combined-player baseline | Raster seed 61 | Change |
| --- | ---: | ---: | ---: |
| ALMs | 35,817 (85%) | 30,299 (72%) | -5,518 |
| Registers | 51,622 | 43,155 | -8,467 |
| Block-memory bits | 4,158,522 | 3,872,709 | -285,813 |
| RAM blocks | 546 / 553 (99%) | 514 / 553 (93%) | -32 |
| DSP blocks | 75 | 60 | -15 |
| PLLs | 4 | 3 | -1 |

Free RAM blocks increased from seven to 39. Baseline numbers come from the published v0.9.5 qualification, not a fresh baseline rebuild.

## Timing coverage and warnings

Passing summaries establish closure for the constrained paths, not complete board-level interface sign-off. `report_ucp` lists zero illegal/unconstrained clocks, four unconstrained input ports and 49 unconstrained output ports. These include HDMI audio/video outputs and I2C. `check_timing` lists 2,473 no-clock nodes confined to HPS/interface prefixes (`sysmem_lite:sysmem`, `h2f_gp`, `hdmi_i2c`), 86 multiple-clock entries, one unused virtual clock, 14 missing input-delay entries and 129 missing output-delay entries. It reports zero loops, latches, generated-clock issues and multicycle-consistency issues.

The seven timing warnings are unmatched optional ALSA SPI clock/group filters in `sys/sys_top.sdc` and unmatched top-level RESET exceptions in `MediaPlayer.sdc`. Those lines predate the cleanup. No timing exceptions were added to obtain these results. The removed music clock/selector constraints no longer cause lookups. External-interface behavior remains part of hardware acceptance.

## Artifact and provenance

- Candidate: `/run/media/vash/GIT/raster-movie-build-up5c4hr5/hardware-test-seed61/Raster_20260919.rbf`
- Size: 4,319,788 bytes.
- SHA-256: `d3f9b369a8ceb4b4c830a8f781512f0b43817d13fb1f59502a7b7a1666d3b259`.
- Build batch: `/run/media/vash/GIT/raster-movie-build-up5c4hr5`.
- `source_manifest.json` and `working-tree.patch` preserve the input snapshot and tracked changes; untracked new files are included in the source snapshot.
- All compiled HDL/project/ROM inputs were compared against the snapshot and the current working tree. They match, allowing only each recorded fitter-seed override.
- `tools/check_timing_corners.tcl` was added after compilation began; it is a read-only report script, copied into each build for the dedicated sweep.
- Detailed reports remain under each `seed*/timing_corners/`; machine-readable results are in `timing_results.json`.

## Hardware acceptance

On 2026-09-19, the owner reported "everything passes" after receiving the seed 61
candidate. Raster_20260919.rbf (SHA-256 above) is now the accepted movie-only
baseline. This is owner-reported hardware acceptance; no per-file or per-output
log was supplied, and no agent-run playback regressions are claimed. The timing
coverage limitations above remain unchanged. The original package is preserved
with an added ACCEPTANCE.md record; the RBF and source snapshot are unchanged.
TAR playlists remain future work. Nothing was committed or pushed.
