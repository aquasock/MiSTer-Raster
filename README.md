# MiSTer-Raster

An FPGA MPEG movie player for MiSTer, targeting QMTech DE10-Nano-compatible
Cyclone V hardware (`5CSEBA6U23I7`). Raster is the video companion to
MiSTer-Phosphor, which handles standalone audio playback and visualizers.

## Playback

- MPEG-2/H.262 progressive 4:2:0 video up to 720×480, with I/P/B pictures,
  display-order reordering, and the eight standard H.262 frame rates.
- MP2 movie soundtracks from the same Program Stream, with timestamped
  A/V synchronization and HDMI, analog, and S/PDIF output.
- Pause/resume, seeking, time/progress overlay, aspect ratio, refresh-rate
  selection, and color-matrix selection.
- SRT subtitles with visibility, timing offset, and speed controls.
- Phosphor-style TAR/M3U movie playlists with next/previous, automatic advance,
  looping, and automatically linked SRT subtitles.
- A browser media builder with FFmpeg video conversion and offline WASM
  TAR packaging for movies and linked subtitles.

The decode path runs in FPGA logic. Stock MiSTer Main supplies file access;
no software decoder or helper is required. Use **Load movie or playlist** to select an
`.mpg` file or a playlist `.tar`. Press **I** with the OSD closed to toggle the TAR playlist/title panel; **N/P**
selects the next/previous movie and **A** switches between 4:3 and 16:9. Standalone music playback and audio visualizers
have been removed.
Open [the media builder](tools/media-builder/index.html) locally in a browser
to create archives; [format and controls](docs/TAR_PLAYLIST_BOUNDARY.md).

## Supported profile

Video is progressive 4:2:0 up to 720×480. Interlaced/field pictures, other
chroma formats, larger pictures, and custom quantization matrices are outside
this decoder's implemented profile. Movie audio is MPEG-1 Layer II at 48 kHz,
stereo/dual-channel/joint-stereo; see [MPEG](docs/MPEG.md) for bitrate and CRC
restrictions. Subtitles are bounded plain-text SRT with two lines.

## Building and validation

Use Quartus Prime Lite 17.0.2 Build 602 with `MediaPlayer.qpf`:

```sh
quartus_sh --flow compile MediaPlayer
```

The Quartus project retains its existing MediaPlayer filename. Keep build
outputs outside the source tree; see [Build](docs/BUILD.md) for the three-seed
and multi-corner qualification procedure. Three movie-only builds pass all eight available timing corners for constrained
paths; see [build results](docs/RASTER_BUILD_RESULTS.md) for the selected local
candidate and coverage limitations. The owner accepted seed 61 on 2026-09-19
after hardware testing. The owner also accepted playlist seed 87 after testing
TAR/M3U playback and linked subtitles; its three seeds pass all eight constrained
timing corners. See [playlist build results](docs/RASTER_PLAYLIST_BUILD_RESULTS.md).
The subsequent I-toggle playlist panel passes all eight constrained timing
corners on selected seed 61 and awaits hardware acceptance; see
[playlist UI build results](docs/RASTER_PLAYLIST_UI_BUILD_RESULTS.md).

## Documentation and media preparation

- [Install](INSTALL.md)
- [Architecture](docs/ARCHITECTURE.md)
- [MPEG video and movie audio](docs/MPEG.md)
- [Subtitles](docs/SUBTITLES.md)
- [Playback UI](docs/UI.md)
- [Cleanup baseline](docs/RASTER_CLEANUP_BASELINE.md)
- [Cleanup dependency inventory](docs/RASTER_CLEANUP_INVENTORY.md)
- [TAR/M3U playlists and linked subtitles](docs/TAR_PLAYLIST_BOUNDARY.md)

`tools/create_mpg.txt` contains the existing ffmpeg encoding recipe.

## License

Project source carries GNU GPL version 2 or later headers; platform components
retain their upstream licensing. Keep the source notices and `LICENSE.txt`
with distributions; see [attributions](ATTRIBUTIONS.md). Historical release notes describe the combined player's
previous releases and are retained for provenance.
