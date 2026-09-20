# TAR / M3U movie playlists

Raster uses Phosphor's uncompressed USTAR + embedded M3U approach. Select a
`.tar` through **Load movie or playlist**. The M3U determines movie order,
regardless of member order in the archive. N/P selects next/previous when the
OSD is closed; normal end-of-movie advances after video and movie audio drain.
Both directions wrap, and the last movie loops to the first. Reset rescans the
mounted archive and returns to the first entry. A standalone `.mpg` still works.

## Linked subtitles

A movie `folder/Example.mpg` associates with `folder/Example.srt` in the same
archive. Matching folds ASCII case and normalizes backslashes to slashes, as
Phosphor does for M3U paths. Each movie has at most one linked SRT. The core
loads it automatically; **Subtitles → Visible** controls display and persists
across movies. Offset and speed controls also retain their menu settings.
A movie without a matching SRT clears the previous captions. Manual SRT loading
remains available as an override for the current movie; the next movie selects
its own archive association again.

## Building playlists

Open [the local builder](../tools/media-builder/index.html) in a browser. Add
MPG and SRT files, reorder movies, then build/download the TAR. Matching names
pair automatically; **SRT…** links a differently named subtitle manually.
The output renames each linked SRT to its movie's archive stem. Duplicate movie
names receive unique suffixes. Files are copied byte-for-byte, without
transcoding. Existing TAR playlists can be reopened and reordered.

The Playlist TAR tab uses a small locally embedded WASM USTAR codec, has no
network runtime dependencies, and works from `file://`. The Convert video tab
adds the old MPEG builder’s FFmpeg recipe and downloads the pinned video engine
on demand. Converted movies can be added directly to the playlist. Blob slices preserve file
payloads without converting entire movies into JavaScript byte arrays.
Browser storage/download limits still apply to very large archives.

## Supported archive profile

These are implementation limits, not general TAR or M3U standard limits:

- Ordinary uncompressed USTAR, regular files and directories; no GNU/PAX
  extension records, links, nonempty USTAR prefix fields or compressed TAR.
- Member paths at most 100 UTF-8 bytes; relative paths in M3U must match the
  member paths exactly after ASCII case/slash normalization. No BOM, URL,
  `./` removal, whitespace trimming or path canonicalization is performed.
- Exactly one nonempty `.m3u`, at most 64 KiB, containing 1–255 movie entries.
  Plain and extended M3U are supported. Blank lines and `#` comments/metadata
  are ignored by hardware; CR, LF and CRLF line endings are accepted.
- Up to 255 `.mpg` and 255 `.srt` members. Listed movies and subtitle members
  must be nonempty. Unrelated regular members are skipped.
- Builder members are smaller than 8 GiB (ordinary USTAR octal size encoding).
  The archive must fit within the reader's 2 TiB address range.
- Header checksums, member bounds, M3U references and index limits are checked.
  Missing listed movies and multiple members matching one filename fingerprint
  are rejected. An invalid archive stays stopped; loading another file or
  Reset retries. There is currently no detailed on-screen archive error.

The hardware stores FNV-1a hash plus byte length, rather than full filenames.
The builder checks collisions among emitted movie names/stems. This compact
lookup is the same approach as Phosphor; it is not cryptographic validation of
arbitrary externally authored filenames. Repeated M3U references to the same
movie are allowed. Unreferenced valid movie/SRT members do not play.

## Reader/session integration

`media_movie_playlist` reads only 512-byte headers and the M3U, skipping movie
payloads. It resolves movie paths and optional subtitle stems into separate
bounded member tables. Selection supplies movie base/length and subtitle
base/length before asserting the existing new-session event.

`media_file_reader` now receives `file_base` plus member-relative `file_size`
and `start_offset`. Its byte-position and EOF are member-relative. Physical SD
LBAs alone include the base, so duration preflight, seeks, decoder ingress and
subtitle re-scans all use consistent coordinates. Bounds reject overflow.

`media_sd_owner` serializes logical movie and subtitle readers. Linked subtitles
share mounted slot 0 with the movie/archive; manual SRT uses slot 1. Logical
owner and physical slot remain latched through acknowledgement and trailing
buffer writes, including cancellation. Subtitle reads yield when the movie
FIFO is low. Session/DDR drain, decoder reset, generation tags, A/V completion
and subtitle clear/epoch handshakes remain in place.

## Validation

The deterministic parser, resolver, navigation, bounds and malformed-archive
simulations, the reader and subtitle integration benches, and the offline
Chrome/WASM builder tests (exact payload round-trips, checked against the
production RTL) were run during development. They are not part of this
repository; [QUALIFICATION.md](QUALIFICATION.md#verification-during-development)
records what they covered. Hardware acceptance is separate from simulations and
timing reports.

## Playlist display

Press **I** with the OSD closed to toggle the movie playlist panel. It follows
N/P and automatic transitions, preserving visibility within the current TAR.
The core captures M3U titles while scanning the manifest, without additional
movie reads. `media_movie_metadata` stores a playlist name and 255 movie names
in 8 KiB; missing EXTINF titles use the path basename. The display stores
31 printable ASCII bytes per name. See [UI](UI.md) for display behavior.

Metadata parsing, the toggle and the RTL rendering at 640×480, 1280×720 and
1920×1080 were verified during development (see Validation above).
