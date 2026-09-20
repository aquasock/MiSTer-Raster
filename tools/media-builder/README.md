# Raster media builder

Open `index.html` directly in desktop Chrome or Edge. The two tabs retain their
state when you switch between them. In **Playlist TAR**, add
`.mpg` movies and optional `.srt` subtitles. Matching stems pair automatically;
use **SRT…** to choose a different subtitle for a movie. Arrange movies with
up/down, enter a title, and build/download the TAR. All processing is local.
The same folder can also be served by any static web server. Playlist creation
works offline; conversion downloads its video engine when requested.

Raster follows the embedded-M3U TAR format used by Phosphor. The archive
contains `playlist.m3u`, unchanged movie bytes, and optional matching SRTs.
Captions load with their movie; the core's subtitle visibility menu turns them
on/off. Open an existing TAR to edit its order and links. See
[the profile](../../docs/TAR_PLAYLIST_BOUNDARY.md) for format limits.

## Convert video

The **Convert video** tab reuses the encoding recipe from
`MiSTer-Raster_OLD/tools/phosphor_mpg_builder`. Choose a source video, 24 or
30 fps, 4:3 or 16:9 and Standard or Maximum quality, then **Build MPG**.
Download the result or **Add to playlist** directly. Add a matching SRT in the
playlist tab to link captions. Embedded input subtitles are not extracted.
Cancel stops the worker; another conversion can be started afterward.

**Convert on your computer** shows an exact command for Bash/POSIX shells,
using the same frame rate, aspect ratio and quality. Choose **Native FFmpeg
threads** from 1–8, edit the input/output paths if needed, and copy the command.
Run it in the source folder or use full paths; browsers expose the selected
filename, not its absolute path. Filenames are shell-quoted, and `-n` preserves
existing output files. The selected count is passed to decoding, filtering and
encoding; actual CPU utilization depends on FFmpeg and the source. This
selector only affects the displayed native commands. **Build MPG in browser**
always uses the existing single-thread WASM engine and needs no local server.

**Convert all videos in a folder** provides a second copyable command. Run it
in the source folder with FFmpeg and ffprobe installed (Bash/POSIX shell on
Linux, macOS or WSL). It converts video files directly in that folder, including
hidden files, into `Raster/`, using the selected profile and thread count.
Subfolders and non-video files are skipped. Output keeps the complete input
name plus `.mpg` (`clip.mp4` → `Raster/clip.mp4.mpg`), preventing collisions
between different input extensions. Existing outputs are skipped, originals
are preserved, and conversions run sequentially. A failed conversion is
reported; check any incomplete output before retrying. This command does not
copy or extract subtitles; link SRTs in the Playlist TAR tab afterward.

Output is 720×480 progressive MPEG-2 Main Profile/Main Level, YUV 4:2:0,
24000/1001 or 30000/1001 CFR, matching 24/30-frame GOP, 8 Mbit/s maximum video
rate, 1,835,008-bit VBV, and BT.601 limited range. Source audio, when present,
becomes 48 kHz stereo MP2 at 192 kbit/s. Standard uses quantizer target 3
(range 2–12); Maximum uses target 1 (range 1–8). Output is an MPEG Program Stream.

The pinned `@ffmpeg/ffmpeg` 0.12.15 wrapper and `@ffmpeg/core` 0.12.10 engine
load from unpkg only when conversion is requested. Media never leaves the
browser. A single classic Blob worker permits locally opened HTML without
cross-origin-isolation server headers. Files must be smaller than 2 GiB and
conversion needs substantial additional memory; long videos are better suited
to native FFmpeg. Engines are reused for subsequent conversions on the page.
See [ffmpeg.wasm usage](https://ffmpegwasm.netlify.app/docs/getting-started/usage/)
and [limitations](https://ffmpegwasm.netlify.app/docs/faq/).

## Implementation and validation

`tabs.js` provides accessible tab navigation, `conversion-profile.js` carries
the old app's recipe, and `convert.js` handles engine loading, cancellation,
cleanup, download and direct playlist transfer. Network failures in the
converter do not affect offline TAR creation.

`tar.c` is the freestanding WASM header encoder/validator. `core.js` handles
playlist policy and Blob assembly; `app.js` supplies the UI. `wasm.js` embeds
`tar.wasm` so local-file use does not require fetch/CORS or a server. Keep all
these files together. The included WASM has no imported runtime functions.

To rebuild with Zig (verified with Zig 0.16.0):

```sh
python3 tools/media-builder/build_wasm.py --zig /path/to/zig
```

The build prints the binary SHA-256 and regenerates both WASM representations.
Python browser checks require Selenium, Chrome and a matching chromedriver:

```sh
python3 tools/verify_media_builder.py --driver /path/to/chromedriver --output /tmp/raster-builder-test
python3 tools/verify_movie_playlist.py --builder-tar /tmp/raster-builder-test/builder-roundtrip.tar
python3 tools/verify_native_command.py --driver /path/to/chromedriver
python3 tools/verify_native_batch_command.py --driver /path/to/chromedriver
python3 tools/verify_playlist_io.py
python3 tools/verify_media_conversion.py --driver /path/to/chromedriver --output /tmp/raster-builder-test
```

The hardware simulations require Icarus Verilog (`iverilog` and `vvp`).
Conversion checks also require native `ffmpeg`/`ffprobe` and internet access for
the pinned browser engine. They validate actual output streams, conversion
options, audio-free sources, cancel/retry and exact movie/SRT TAR handoff.
Tests generate their media fixtures; supplied user movies are not modified.

Original utility code is GPL-2.0-or-later. The visual style is adapted from
MiSTer-Phosphor's `tools/media-builder/shared.css` at commit `4b2a360` under the
same license. See the repository's `LICENSE.txt` and `ATTRIBUTIONS.md`.
