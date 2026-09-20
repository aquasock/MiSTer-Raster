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
to create archives; [format and controls](docs/PLAYLISTS.md).

## Supported profile

Video is progressive 4:2:0 up to 720×480. Interlaced/field pictures, other
chroma formats, larger pictures, and custom quantization matrices are outside
this decoder's implemented profile. Movie audio is MPEG-1 Layer II at 48 kHz,
stereo/dual-channel/joint-stereo; see [MPEG](docs/MPEG.md) for bitrate and CRC
restrictions. Subtitles are bounded plain-text SRT with two lines.

## Building and validation

Use Quartus Prime Lite 17.0.2 Build 602 with `Raster.qpf`:

```sh
quartus_sh --flow compile Raster
```

The Quartus project is named Raster, so a build produces `Raster.rbf`. `Raster.qsf`
pins seed 52, the timing-qualified seed for the current source. Keep build outputs
outside the source tree; [Build](docs/BUILD.md) describes the isolated three-seed
and multi-corner procedure (`tools/build_seeds.sh`), and
[Qualification](docs/QUALIFICATION.md) records every build's seeds, resources,
timing-coverage limits and hardware acceptance. Seed 52 is the accepted build of the
current source.

## Documentation and media preparation

- [Install](INSTALL.md)
- [Architecture](docs/ARCHITECTURE.md)
- [MPEG video and movie audio](docs/MPEG.md)
- [Subtitles](docs/SUBTITLES.md)
- [Playback UI](docs/UI.md)
- [TAR/M3U playlists and linked subtitles](docs/PLAYLISTS.md)
- [Building](docs/BUILD.md)
- [Build qualification](docs/QUALIFICATION.md)
- [Changelog](docs/CHANGELOG.md)

The media builder's **Convert video** tab and [its README](tools/media-builder/README.md) describe the accepted MPEG-2/MP2 encoding profile and the FFmpeg recipe.

## License

Project source carries GNU GPL version 2 or later headers; platform components
retain their upstream licensing. Keep the source notices and `LICENSE.txt`
with distributions; see [attributions](ATTRIBUTIONS.md). [Historical release notes](docs/history/MEDIA_PLAYER_RELEASE_NOTES.md) describe the
combined player's earlier releases and are retained for provenance.
