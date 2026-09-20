# MiSTer-Raster

An FPGA MPEG movie player for [MiSTer](https://github.com/MiSTer-devel), targeting
QMTech DE10-Nano-compatible Cyclone V hardware (`5CSEBA6U23I7`). Raster plays
MPEG-2 Program Stream movies with MP2 soundtracks, SRT subtitles and TAR/M3U
playlists. Decoding runs entirely in FPGA logic: stock MiSTer Main supplies file
access, and no software decoder or helper is required. Raster is the video
companion to [MiSTer-Phosphor](https://github.com/aquasock/MiSTer-Phosphor), which
handles standalone audio playback and visualizers.

## What it does

- **MPEG-2 / H.262 video** — progressive 4:2:0 up to 720×480 with I, P and B
  pictures, display-order reordering, and the eight standard H.262 frame rates
  (23.976, 24, 25, 29.97, 30, 50, 59.94 and 60).
- **MP2 movie audio** — MPEG-1 Layer II from the same Program Stream, with
  timestamped A/V synchronization and HDMI, analog and S/PDIF output.
- **Transport** — pause and resume, direct seeking, and a time and progress overlay.
- **Subtitles** — bounded plain-text SRT with visibility, timing offset and speed
  controls.
- **Playlists** — an uncompressed TAR with an embedded M3U (up to 255 movies): the
  M3U sets the order, N and P step through it, playback advances and loops
  automatically, and each movie's matching SRT is linked and loaded on its own. An
  on-screen panel lists the titles.
- **Display** — 4:3 or 16:9 from the keyboard, refresh rate (59.94 or 50 Hz), and color
  matrix (Auto, BT.601 or BT.709).
- **Browser media builder** — an offline tool that packages movies and subtitles
  into playlists and converts other video into Raster's format with FFmpeg.

## Controls

Hotkeys work while the MiSTer OSD is closed.

| Key | Action |
| --- | --- |
| `Space` | Pause or resume |
| `Left` / `Right` | Seek backward or forward 10 seconds |
| `Ctrl` + `Left` / `Right` | Seek backward or forward 30 seconds |
| `Ctrl` + `Alt` + `Left` / `Right` | Seek backward or forward 60 seconds |
| `F1`–`F8` | Jump to the start (`F1`) and each eighth of the movie (`F8` = 7/8) |
| `N` / `P` | Next or previous movie in a playlist (wraps in both directions) |
| `I` | Show or hide the playlist panel |
| `A` | Switch between 4:3 and 16:9 |

The playlist keys and panel apply only to a loaded TAR; a standalone `.mpg` has
none. The aspect setting is not saved and starts at 4:3 at power-up.

The OSD menu has:

- **Load movie or playlist** — select an `.mpg` or a playlist `.tar`.
- **Subtitles** — **Load** an SRT manually, **Visible** (Yes or No, kept across
  movies), **Offset** (-5.0 to +5.0 s in 0.2 s steps) and **Speed** (0.50× to 1.50×
  in 0.02× steps).
- **Refresh rate** and **Color matrix**.
- **Reset** and **Reset and close OSD** — restart the current movie, or return to
  the first entry of a playlist.

## Supported profile

Video is progressive 4:2:0 up to 720×480. Interlaced or field pictures, other
chroma formats, larger pictures, custom quantization matrices, concealment motion
vectors and scalable streams are outside this decoder's implemented profile. Movie
audio is MPEG-1 Layer II at 48 kHz, stereo, dual-channel or joint stereo; see
[MPEG](docs/MPEG.md) for bitrate and CRC restrictions. Subtitles are bounded
plain-text SRT with two lines.

## Current limitations

- **Throughput.** Real-time decoding of demanding 480p59.94/60 streams is not
  established: A/V drift and limited throughput were observed on a stress file, and
  hardware acceptance does not cover that case.
- **Playlist archives** must be ordinary uncompressed USTAR, at most 255 movies and
  255 subtitles, an M3U of at most 64 KiB, and member paths of at most 100 bytes;
  see [playlists](docs/PLAYLISTS.md). An invalid archive stays stopped, and there is
  no on-screen error message.
- **Titles** are shown as 31 printable ASCII characters; other bytes appear as `?`.
- **Timing sign-off** covers the constrained paths only, not every board I/O path;
  see [Qualification](docs/QUALIFICATION.md#timing-coverage-and-limits).
- **No standalone music playback or visualizers.** Those are MiSTer-Phosphor's job.

## Installation

Copy a dated release RBF to the SD card's `_Other` directory and select it from
MiSTer:

```text
/media/fat/_Other/Raster_YYYYMMDD.rbf
```

Keep the previous working RBF when trying a new one. See [INSTALL.md](INSTALL.md).

## Preparing media

Open [the media builder](tools/media-builder/index.html) in a current Chromium-based
browser. It runs entirely locally, needs no server or account, and has two tabs:

- **Playlist TAR** — add MPG movies and matching SRT files, arrange the order, and
  download a TAR. Names pair automatically, files are copied byte for byte, and an
  existing playlist TAR can be reopened, reordered and saved.
- **Convert video** — turn other video formats into Raster's 720×480 progressive
  MPEG-2/MP2 profile with FFmpeg (downloaded on first use), with a copyable native
  FFmpeg command and a batch command that converts a whole folder. Converted movies
  can go straight into a playlist.

See [the builder README](tools/media-builder/README.md) for the exact encoding
profile and [playlists](docs/PLAYLISTS.md) for the archive format.

## Building

Use Quartus Prime Lite 17.0.2 Build 602 with `Raster.qpf`:

```sh
quartus_sh --flow compile Raster
```

The Quartus project is named Raster, so a build produces `Raster.rbf`. `Raster.qsf`
pins seed 52, the timing-qualified seed for the current source, and that build is
recorded as accepted. Keep build outputs outside the source tree; [Build](docs/BUILD.md)
describes the isolated three-seed and multi-corner procedure (`tools/build_seeds.sh`),
and [Qualification](docs/QUALIFICATION.md) records every build's seeds, resources,
timing-coverage limits and hardware acceptance.

## Source layout

- `Raster.sv` and `Raster_*.svh` — core integration: ports and OSD, file and session
  control, clocks, container, decoder, prediction, framebuffer and output wiring.
- `rtl/` — the MPEG-2 and MP2 decoders, playlist and subtitle logic, transport UI
  and platform-specific control.
- `sys/` — the standard MiSTer framework, scaler, video, audio, HPS I/O and
  top-level platform wrapper.
- `tools/media-builder/` — the browser media builder.
- `tools/` — `build_seeds.sh`, `run_timing_sweep.py` and `check_timing_corners.tcl`.
- `docs/` — design, build and qualification documentation.

## Documentation

- [Install](INSTALL.md)
- [Architecture](docs/ARCHITECTURE.md)
- [MPEG video and movie audio](docs/MPEG.md)
- [Subtitles](docs/SUBTITLES.md)
- [Playback UI](docs/UI.md)
- [TAR/M3U playlists and linked subtitles](docs/PLAYLISTS.md)
- [Building](docs/BUILD.md)
- [Build qualification](docs/QUALIFICATION.md)
- [Changelog](docs/CHANGELOG.md)
- [Media Player history](docs/history/MEDIA_PLAYER_CHANGELOG.md), the common origin
  of Raster and Phosphor

## License

Original project code is distributed under the GNU General Public License version 2
or later, matching MiSTer-Phosphor. Because the combined design includes MiSTer
framework modules under GPL version 3 or later, distribute the complete source and
RBF under GPL-3.0-or-later. LGPL and Intel/Altera-generated components retain their
own terms. Keep the source notices with distributions and include `COPYING`,
`LICENSE.txt` and `COPYING.LESSER`; see [ATTRIBUTIONS.md](ATTRIBUTIONS.md).
