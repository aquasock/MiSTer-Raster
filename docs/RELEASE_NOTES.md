# Release notes

Newest first. Earlier releases (v0.1.0 to v0.9.5) belong to MiSTer Media Player, the
common ancestor of MiSTer-Raster and MiSTer-Phosphor; their notes are in
[history/](history/MEDIA_PLAYER_RELEASE_NOTES.md). The full list of changes is in
[CHANGELOG.md](CHANGELOG.md).

## MiSTer-Raster v0.10.0

Released 2026-09-20. This is the first Raster release. It continues the version
numbers of MiSTer Media Player, whose last release was v0.9.5.

### Highlights

- **A movie-only player.** Raster is Media Player's video path on its own: MPEG-2
  Program Stream movies with MP2 soundtracks, SRT subtitles and transport controls.
  Standalone music, FLAC albums and the visualizers now live in MiSTer-Phosphor.
- **TAR/M3U playlists.** An uncompressed TAR with an embedded M3U, with next and
  previous, automatic advance and looping, and automatic linking of each movie's
  SRT. The **I** key shows a six-row playlist panel with M3U titles and scrolling
  long titles.
- **Aspect on a key.** **A** switches between 4:3 and 16:9 at any time. It replaces
  the OSD menu entry, is not saved, and starts at 4:3 at power-up.
- **Browser media builder.** An offline tool that builds playlists and converts other
  video to Raster's format with FFmpeg.
- **Qualified build.** Seed 52 closes all eight timing corners and is recorded as
  accepted on hardware; the build reproduces byte for byte from a fresh clone.

### Changed since v0.9.5

- The project is now `Raster` (it builds `Raster.rbf`), with source files `Raster.sv`
  and `Raster_*.svh`, and the OSD names the core Raster.
- Removed: standalone FLAC album playback, the music clocks and CD-audio HDMI
  handoff, the three visualizers and their FFT tables, and the FLAC tools. Movie
  video and audio connect directly to the platform output paths, and HPS owns HDMI
  I2C again.
- The playlist panel draws no track numbers, so titles use the full 27-character row.
- Unchanged: the MPEG-2 and MP2 decoders, A/V timing, seeking, subtitles and the
  transport UI.

### Required runtime files

This release is FPGA-only: stock MiSTer Main supplies file access, and there is no
Main patch or helper to match.

| Release file | Install path | Size | SHA-256 |
| --- | --- | ---: | --- |
| `Raster_20260920.rbf` | `/media/fat/_Other/Raster_20260920.rbf` | 4,434,780 | `e8fbebe8397e581eddbdd4d0a64823e84b887cfdd0f895401a576f2808bf4dfb` |

The OSD identifies the build by its date stamp (`260920`) rather than a version
number. Keep the previous working RBF when trying a new one; see
[INSTALL.md](../INSTALL.md).

### Supported v0.10.0 subset

- **Video:** progressive 4:2:0 up to 720×480, I, P and B pictures, at the eight direct
  H.262 frame rates (23.976, 24, 25, 29.97, 30, 50, 59.94, 60). Not supported:
  interlaced or field pictures, other chroma formats, larger pictures, custom
  quantization matrices, concealment motion vectors and scalable streams.
- **Audio:** MPEG-1 Layer II at 48 kHz, stereo, dual-channel or joint stereo. See
  [MPEG.md](MPEG.md) for bitrate and CRC restrictions.
- **Subtitles:** bounded plain-text SRT with two lines; offset from -5.0 to +5.0 s and
  speed from 0.50× to 1.50×.
- **Playlists:** ordinary uncompressed USTAR with up to 255 movies and 255 subtitles,
  an M3U of at most 64 KiB, member paths of at most 100 bytes and members smaller than
  8 GiB. See [PLAYLISTS.md](PLAYLISTS.md).
- **Output:** HDMI, analog and S/PDIF, at 59.94 or 50 Hz, with Auto, BT.601 or BT.709
  color.

### Known limitations

- **Throughput.** Real-time decoding of demanding 480p59.94/60 streams is not
  established: A/V drift and limited throughput were observed on a stress file, and
  hardware acceptance does not cover that case.
- **Playlist errors.** An invalid archive stays stopped, and there is no on-screen
  error message.
- **Titles** are shown as 31 printable ASCII characters; other bytes appear as `?`.
- **Timing sign-off** covers the constrained paths only, not every board I/O path. See
  [QUALIFICATION.md](QUALIFICATION.md#timing-coverage-and-limits).
- **Aspect** is not saved between power cycles.

### Qualification

Quartus Prime Lite 17.0.2 Build 602, Cyclone V `5CSEBA6U23I7`, HIGH ALM register
packing, six fitter threads, project `Raster` with `SEED 52` pinned. Worst slack in ns
across the eight corners (slow and fast 1100 mV at -40, 0, 85 and 100 C):

| Seed | ALMs | RAM blocks | Setup | Hold | Recovery | Removal | Pulse width | Result |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| **52** | 32,930 | 545 | +0.335 | +0.109 | +3.912 | +0.213 | +0.925 | Pass, zero TNS |
| 61 | 32,962 | 545 | **-0.199** | +0.108 | +3.236 | +0.221 | +0.925 | **Fails setup** |
| 87 | 32,888 | 545 | +0.064 | +0.106 | +3.459 | +0.210 | +0.925 | Pass, zero TNS |

Seed 52 uses 79% of the ALMs, 545 of 553 RAM blocks (99%), 60 DSP blocks and 3 PLLs.
Seed 61, which the earlier builds used, no longer closes setup on this source; do not
use it.

**Reproducibility.** The release bitstream was built from a fresh clone of the GitHub
repository at commit `2ff75d94a5a72d3cc16c95109a388fa4bb5adedf` with
`tools/build_seeds.sh` for seed 52, with no manual edits. It is byte-identical to
earlier builds of the same source made before and after the project and file renames,
and its timing matches the table above. The date stamp is the build date, so a build
on another day differs in those bytes only.

**Hardware.** The owner reported that the fix worked on hardware (2026-09-19) and
asked for the seed 52 build to be recorded as accepted (2026-09-20). The file tested
was an earlier build of the same seed 52 design and is no longer on disk; the release
bitstream matches it in resources and timing but was not compared byte for byte. No
agent-run hardware playback is claimed. Full records, including earlier builds and the
timing-coverage limits, are in [QUALIFICATION.md](QUALIFICATION.md).

### Licensing and packaging

Distribute the RBF with the corresponding source under GPL-3.0-or-later, and include
`COPYING`, `LICENSE.txt`, `COPYING.LESSER` and [ATTRIBUTIONS.md](../ATTRIBUTIONS.md).
Preserve the per-file license headers. Release copies of the bitstream are named
`Raster_YYYYMMDD.rbf` and are not stored in the repository.
