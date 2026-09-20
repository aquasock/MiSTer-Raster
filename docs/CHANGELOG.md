# Changelog

All notable changes to MiSTer-Raster. Raster began on 2026-09-19 as a movie-only
fork of MiSTer Media Player v0.9.5; that project's history (v0.1.0 to v0.9.5) is
kept in [history/](history/MEDIA_PLAYER_CHANGELOG.md). There is no tagged Raster
release yet, so everything below is unreleased. Build results, seeds and hardware
acceptance for each step are in [QUALIFICATION.md](QUALIFICATION.md).

## [Unreleased]

### Added

- TAR/M3U movie playlists: uncompressed USTAR with an embedded M3U, bounded
  member reads, N/P navigation, automatic advance and loop, and automatic SRT
  association with persistent subtitle visibility. See [PLAYLISTS.md](PLAYLISTS.md).
- The **I** key toggles a six-row playlist panel with M3U titles, current-movie
  highlighting and scrolling titles (one character per ten output frames, a
  45-frame pause at each end). The heading is centered.
- The **A** key switches between 4:3 and 16:9 with the OSD closed. The setting is
  not saved and starts at 4:3 after power-up.
- Browser media builder (`tools/media-builder/`): offline WASM MPG/SRT packaging
  and playlist editing, the FFmpeg video-conversion workflow with direct transfer
  into the playlist, and a copyable native FFmpeg command with a 1 to 8 thread
  selector (browser conversion keeps its single-thread engine).
- Build tooling: `tools/build_seeds.sh` (isolated per-seed builds plus the timing
  sweep), `tools/run_timing_sweep.py` and `tools/check_timing_corners.tcl`.
- Documentation consolidated into `docs/`, with a living
  [QUALIFICATION.md](QUALIFICATION.md).
- `COPYING.LESSER` (the LGPL-3.0 text for the framework's `sys/sd_card.sv`), and an
  expanded `ATTRIBUTIONS.md` covering the MiSTer framework's per-file licenses,
  Intel/Altera generated IP and a redistribution checklist.
- `.gitignore` (Quartus output, generated files, `dist/`) and `.gitattributes`
  (every file stored byte for byte, so no tool rewrites line endings).

### Changed

- The playlist panel no longer draws track numbers; titles use the full
  27-character row.
- The transport progress bar and clocks render in native 640×480 coordinates,
  scaled together into a centered 4:3 area regardless of movie aspect.
- The Quartus project is now `Raster` (it builds `Raster.rbf`), and the top-level
  source files are `Raster.sv` and `Raster_*.svh`. The design is byte-identical
  before and after the renames.
- `Raster.qsf` pins seed 52, the qualified seed for the current source.
- Builder playlist titles no longer keep a source video extension
  (`clip.mp4.mpg` shows as `clip`).

### Removed

- Standalone FLAC album playback, music clocks and the CD-audio HDMI handoff, the
  three visualizers with their FFT tables and assets, and the FLAC tools. Movie
  video and MP2 audio connect directly to the retained platform output paths and
  HPS again owns HDMI I2C; obsolete timing constraints were removed. MPEG-2, MP2
  audio, A/V timing, seeking, subtitles and the transport UI are unchanged.
- The **Aspect ratio** OSD entry (replaced by the A key). Status bit 121 is
  reserved.

### Qualification

- Movie-only baseline: seeds 52, 61 and 87 pass all eight timing corners for the
  constrained paths; seed 61 accepted on hardware on 2026-09-19.
- Current source: seed 52 passes and is accepted; seed 87 passes; seed 61 fails
  setup and must not be used. The external-I/O timing coverage limits are
  documented in [QUALIFICATION.md](QUALIFICATION.md#timing-coverage-and-limits).
