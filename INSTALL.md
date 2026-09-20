# Installing MiSTer-Raster

Use a built Raster RBF on the supported Cyclone V MiSTer hardware. Copy it to
the SD card's `_Other` directory and select it from MiSTer. The Quartus project
produces `Raster.rbf`; copy it to a dated `Raster_YYYYMMDD.rbf` filename
when packaging a qualified build. The first Raster release is v0.10.0; see the
[release notes](docs/RELEASE_NOTES.md).

Open the core OSD and choose **Load movie or playlist** to select an MPEG-2 Program Stream
`.mpg` with a supported MP2 soundtrack. See [MPEG](docs/MPEG.md) and the
[media builder](tools/media-builder/README.md) for the accepted profile and encoding recipe.

For subtitles, open **Subtitles**, choose **Load**, and select the matching
`.srt`. Subtitle visibility, offset and speed are adjustable separately.
Refresh rate and color matrix remain in the main core menu; press **A** with the OSD closed to switch between 4:3 and 16:9.
Loading a different movie uses the session drain/restart path automatically.

For playlists, open `tools/media-builder/index.html` in your browser, add MPG
movies and matching SRT files, arrange the order and download a TAR. The
**Convert video** tab can prepare supported MPGs from other video formats and
add them directly to the playlist; its first use downloads FFmpeg. Copy it to
the MiSTer and select it with **Load movie or playlist**. N/P selects next or
previous; EOF advances and the playlist loops. Linked captions load
automatically: use **Subtitles → Visible** to enable or disable them. This
setting persists across movies. See [playlists](docs/PLAYLISTS.md).

Standalone music playback is provided by MiSTer-Phosphor.

Keep the previous working RBF when testing a new candidate. To remove Raster,
delete its RBF; media files remain unchanged.
