# Raster source attributions

Original Raster code retains its GPL-2.0-or-later licensing and `LICENSE.txt`.
Existing MiSTer framework and vendor files retain their individual copyright
and license notices. Framework files include GPL-3.0-or-later components, so
the combined design follows GPL-3.0-or-later; `COPYING` supplies that text.

The TAR/M3U implementation references MiSTer-Phosphor commit
`4b2a360347b6cef7ebbb73219edc18bc4f03294b`:

- `rtl/media_m3u_index.sv` and `rtl/media_playlist_resolver.sv` are adapted from
  the corresponding Phosphor modules, adding SRT stem resolution, optional
  matches and duplicate-match rejection.
- `rtl/media_album_ui_toggle.sv` reuses Phosphor’s I-key toggle, and
  `rtl/media_movie_playlist_ui.sv` adapts its `media_flac_album_ui.sv` renderer
  for a centered movie-title list after HDMI scaling.
- `rtl/media_tar_header.sv` follows Phosphor's `media_tar_index.sv` filename
  normalization and FNV-1a lookup scheme.
- `tools/media-builder/style.css` is Phosphor's shared builder style. Raster's
  builder follows the TAR utility's interface and archive arrangement, adding
  movie/SRT linking and a freestanding C/WASM header codec.

These Phosphor project files are GPL-2.0-or-later. Their reuse does not change
licenses on existing framework or vendor source. Keep the notices and source
with redistributed builds and builder packages.

The converter recipe and workflow are adapted from the owner's local
`MiSTer-Raster_OLD/tools/phosphor_mpg_builder` (GPL-2.0-or-later project code).
The app downloads pinned ffmpeg.wasm wrapper/core distributions from unpkg
on demand; those binaries are not bundled in this repository or builder ZIP.
See the [ffmpeg.wasm project](https://github.com/ffmpegwasm/ffmpeg.wasm) and its
[licensing FAQ](https://ffmpegwasm.netlify.app/docs/faq/) for wrapper and core
licensing/source provenance.
