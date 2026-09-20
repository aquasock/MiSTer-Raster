# Raster MPEG-only cleanup baseline

Recorded 2026-09-19 before implementation changes.

## Approved scope

Target: `/run/media/vash/GIT/MiSTer-Raster`.
Companion audio project: `/run/media/vash/GIT/MiSTer-Phosphor`.

Keep MPEG video playback, MP2 movie audio, A/V synchronization, SRT subtitles,
movie transport controls, and the platform support required by these paths.
Remove standalone FLAC/album playback, visualizers, and their unused support.
The owner already has test files. Regression testing is deferred by request;
no test media was generated, modified, or qualified during this baseline step.

## Source baseline

- Branch: `main`; working tree was clean at inspection.
- HEAD: `ebaea217a4e7a719610ef2a8ac79a4681579dcfa`.
- Describe: `v0.9.5-1-gebaea21`.
- Published baseline source: `1720960bb059c47f90b6ad479da63b896fbfc8a`.
- `git diff --name-status 1720960 HEAD` lists only README, changelog,
  v0.9.5 release notes, and the three media preparation tools. RTL, platform
  files, project settings, and timing constraints match that release source.
- Existing fetch/push origin is still
  `https://github.com/aquasock/MiSTer-Phosphor.git`. Resolve Raster's intended
  remote before publishing cleanup changes. No remote was changed or pushed.
- Project and README still carry MediaPlayer/Phosphor naming.

## Build configuration

Verified from `MediaPlayer.qpf`, `MediaPlayer.qsf`, `files.qip`, and
`sys/sys.tcl`, and by running `quartus_sh --version`:

| Setting | Baseline |
| --- | --- |
| Tool | Quartus Prime Lite 17.0.2 Build 602 |
| Installed shell | `/home/vash/intelFPGA_lite/17.0/quartus/bin/quartus_sh` |
| Project / revision | `MediaPlayer` |
| Top-level entity | `sys_top` |
| FPGA | Cyclone V `5CSEBA6U23I7` |
| Fitter seed | 61 |
| ALM register packing | HIGH |
| Parallel processors | 6 |
| Temperature range | -40 to 100 C |
| Flow multicorner analysis | OFF; separate sign-off required |
| Core timing constraints | `MediaPlayer.sdc` |
| Pre-flow script | `sys/build_id.tcl` |
| Explicit enabled project macro | `MISTER_DISABLE_ALSA=1` |

Future candidate builds must follow `docs/BUILD.md`: keep generated output
outside the source tree, record seed/packing/thread settings, sweep three
seeds, and perform dedicated multi-corner timing checks. No build was launched
for this baseline; only the installed tool version was queried.

## Verified rollback artifact

Existing archive:
`/run/media/vash/GIT/MiSTer-Phosphor_v0.9.5.zip`.

- Archive SHA-256:
  `da1c8766d79b8184b467213e6e125a1a45c41c28ad3d5c2f9e98b2396fae02fa`.
- ZIP integrity check passed; all seven `SHA256SUMS` entries verified.
- RBF member: `MediaPlayer_20260915.rbf`, 4,520,032 bytes.
- RBF SHA-256:
  `7ca9345347c88f689860a6fd6a0d13cdbc43019cbe678dfee4c73508fa3393fc`.
- Archive `SOURCE.txt` identifies source `1720960`, seed 61, HIGH packing,
  six processors, and Quartus 17.0.2 Build 602.

The archive and its members were read without extracting or modifying them.
The artifact is available for later rollback; this inspection does not establish
which bitstream is currently running on the user's hardware.

## Prior resource and timing evidence

The following figures are reported in `docs/RELEASE_NOTES_v0.9.5.md`.
Timing is also recorded in the verified archive's `SOURCE.txt`. These are
historical qualification results, not a new synthesis, fit, or timing run.
No raw Quartus reports or RBF files are present in the current source checkout.

| Resource | Published baseline |
| --- | --- |
| ALMs | 35,817 / 41,910 (85%) |
| Registers | 51,622 |
| Block-memory bits | 4,158,522 / 5,662,720 (73%) |
| RAM blocks | 546 / 553 (99%) |
| DSP blocks | 75 / 112 (67%) |
| PLLs | 4 / 6 (67%) |

All slack values below are in ns; the release records zero total negative slack.

| Corner | Setup | Hold | Recovery | Removal | Min pulse width |
| --- | ---: | ---: | ---: | ---: | ---: |
| Slow 1100mV 100C | +0.236 | +0.237 | +3.468 | +0.561 | +0.925 |
| Slow 1100mV -40C | +0.127 | +0.166 | +3.574 | +0.482 | +0.925 |
| Fast 1100mV 100C | +2.926 | +0.133 | +4.848 | +0.262 | +0.925 |
| Fast 1100mV -40C | +3.526 | +0.045 | +5.105 | +0.179 | +0.925 |

The release notes record owner acceptance of this exact RBF, including the
standing MPG/FLAC regression set. The older `ai/core-log.md` entry 151 still
describes hardware acceptance as pending; use the later release record for
the published baseline's acceptance status.

## Deferred validation

The current `tools/` directory contains only `create_mpg.txt`,
`pack_flac_album.py`, and `unpack_flac_album.py`. Historical logs refer to
simulation/regression tooling absent from this checkout; its availability
must be addressed when validation resumes. No regressions were run now.

Step 1 is complete as a source/configuration/artifact baseline. Next is the
dependency inventory for the movie-only cleanup. Future resource comparisons
should use the figures above and retain the exact source/build provenance of
the new candidate. Playback validation will use the owner's existing media.
