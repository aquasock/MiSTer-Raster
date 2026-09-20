# MiSTer-Raster architecture

Raster keeps MPEG video, MP2 movie audio, subtitles and transport controls.
The current source removes the former standalone FLAC/visualizer path.
Published pre-cleanup resource figures are in [the baseline](RASTER_CLEANUP_BASELINE.md);
new resource/timing claims require a new fitted build.

## Integration

`sys_top` instantiates `emu`, the MiSTer scaler/video processing, the player
overlay, and the platform OSD. `MediaPlayer.sv` assembles the emu body from
ports, file, session, clocks, container, decoder, prediction, framebuffer and
output includes. `MediaPlayer_top_file.svh` holds the shared file/session
signals that previously lived in a music-named include.

The core exposes ordinary video/audio signals plus `PLAYER_UI_CLOCK`,
`PLAYER_UI_STATE`, and `PLAYER_SUBTITLE_COMMAND/ACK`. The HDMI path feeds
scaled/processed movie pixels directly to `media_player_overlay`, then OSD.
RGB, sync, DE and layout DE enter the overlay at the same pipeline stage.

## MPEG and MP2

The mounted-file reader fills the compressed stream FIFO. MPEG ingress
separates Program Stream video and MP2 audio. Video bytes and PTS/EOF metadata
use a DDR reservoir ahead of the H.262 parsing, inverse quantization, shared
IDCT and I/P/B reconstruction logic. Frame storage and presentation scheduling
retain reference-bank ownership and B-picture display-order handling.

MP2 decoding and synthesis use on-chip storage. `MediaPlayer_av.svh` connects
the audio FIFO, decoder, PCM clock-domain FIFO and timestamped PCM sink.
The movie audio clock, origin timestamps and seek coordination are retained.
EOF waits for both final video presentation and the final audio sample.

`sys/audio_out.sv` retains platform volume/filtering and serialization. Its
I2S, S/PDIF and DAC outputs feed the platform output connections directly;
HDMI MCLK uses the existing movie audio PLL. HPS owns HDMI I2C through the
open-drain pad drive/readback path. The CD PLL and music handoff controller
have been removed.

## DDR and session ownership

The movie DDR arbiter retains picture-store, scanout, prediction and compressed
stream clients. Its output now connects directly to the core DDR interface,
without the FLAC owner mux. Quiesce, physical DDR busy, response-valid and idle
still govern draining before decoder reset/restart.

`media_session_control` retains reader/DDR draining and generation changes.
`media_duration_probe` owns the reader during MPEG head/tail preflight;
`media_seek_search` and `media_seek_point` retain sequence/GOP-based seeking.
Keyboard intent and presentation time remain separate. The qualified duration
flag still rejects duration claims contradicted by actual presentation time.

## Subtitles and UI

Movie and linked subtitle members share mounted slot 0; manual subtitles use
slot 1. `media_sd_owner` serializes both logical readers and latches their
physical slot until each response drains. SRT parsing, timing adjustment and delivery
remain separate from decoding. The transport/subtitle renderer retains the
91-bit player state, loaded flag and session/seek epoch so stale scenes cannot
survive a file change or seek. Overlay activity lasts three seconds and remains
visible during seeking. Track/album UI branches have been removed.

## Playlist selection

`media_movie_playlist` walks USTAR headers and parses the embedded M3U before
starting a movie session. Member tables hold movie and optional SRT bounds.
A selected member triggers the same drain/reset path as loading a new movie.
The reader translates member-relative duration/seek/playback positions to
physical archive LBAs. Decoder internals remain independent of the archive.
See [TAR/M3U playlists](TAR_PLAYLIST_BOUNDARY.md).
