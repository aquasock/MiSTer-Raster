# Movie-only cleanup result

Local working-tree change based on `ebaea21`, 2026-09-19. Nothing pushed.

Removed standalone FLAC/CUESHEET playback, music PCM/time interfaces, the CD
clock and HDMI handoff stack, all three visualizers and FFT tables, FLAC tools,
and unused template/audio-test source. Moved shared file declarations into
`MediaPlayer_top_file.svh`. Movie DDR ownership, seek/UI/duration branches and
menus now have one movie path. The core menu identifies itself as Raster.

Movie MP2 and H.262 decoder source remain unchanged. Platform output wiring
now connects movie audio directly to I2S/S/PDIF/DAC consumers, movie PLL to
HDMI MCLK, HPS I2C to HDMI pads, and processed movie video to the overlay.
Matching obsolete native-music timing constraints were removed. Subtitle slots,
state epochs, duration qualification and session draining are retained.

The reader's existing start-offset/end-bound/cancel/idle interface is unchanged.
See `TAR_PLAYLIST_BOUNDARY.md` for later Phosphor-style TAR integration; archive
playlists are not implemented. Phosphor's source and test media were not changed.

## Checks performed

- Core QIP source/ROM references and HDL include/readmemh paths resolve.
- No music/FLAC/album/visualizer/native-audio interface references remain in
  core RTL, top-level includes, emu ports, sys_top or files.qip.
- Direct diff confirms MPEG decoder, MP2 integration, file reader and session
  controller match the source baseline.
- Quartus Prime Lite 17.0.2 Build 602 analysis and synthesis passed: zero
  errors, 3,923 warnings, no critical warnings. Most are width truncation
  warnings (3,814); other categories include unused signals and ROM ports.
  This is not a warning-free build or a baseline warning-count comparison.
- Synthesis reports 41,220 registers, 3,872,709 block-memory bits, 60 DSP blocks
  and three PLLs. These are synthesis figures, not fitted resource usage;
  ALM utilization and physical RAM-block count are not qualified here.
- Source snapshot hashes confirm synthesis used the current HDL/project/ROM
  inputs. `git diff --check` passes.

Build directory: `/run/media/vash/GIT/raster-movie-synth-7m22pzwn`.
Final log: `synthesis.log`; summary: `output_files/MediaPlayer.map.summary`;
input hashes: `SOURCE_SHA256SUMS`. The initial invocation omitted the build-ID
script's project arguments and failed before elaboration; the corrected run
generated build_id.v using the existing script and passed. Build artifacts
remain outside the source tree.

## Build qualification update

Three clean local builds (seeds 52, 61 and 87) now produce RBFs and pass all
five constrained timing categories at all eight available operating conditions.
Seed 61 is the selected hardware-test candidate. See
[build results](RASTER_BUILD_RESULTS.md) for exact margins, resource savings,
checksums, report locations and external-I/O timing coverage limitations.
On 2026-09-19, the owner reported "everything passes" and accepted seed 61 as
the movie-only baseline. No agent-run playback regressions are claimed.
Nothing was committed or pushed.
