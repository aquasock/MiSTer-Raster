# MPEG-only dependency inventory

Implementation status: the planned removals and rewiring are now applied locally;
see [cleanup result](RASTER_CLEANUP_RESULT.md). This inventory records the
pre-edit dependency analysis, and named removal targets may no longer exist.

Step 2, inspected 2026-09-19 against `ebaea21`. See
[baseline](RASTER_CLEANUP_BASELINE.md) for source and release provenance.
This is a static source inventory, not a synthesis or regression result.
No RTL changes, builds, regressions, or pushes are part of this step.

## Retained playback path

```text
HPS mounted-file reader -> compressed stream FIFO -> MPEG ingress/demux
  video -> DDR reservoir -> H.262 decode/reconstruction -> frame storage
        -> display-order scheduling -> video output/scaler -> overlay -> OSD
  MP2   -> compressed audio FIFO -> MP2 decode/synthesis -> PCM CDC FIFO
        -> timestamped PCM output -> MiSTer audio_out -> physical outputs

Movie duration/seek/session control coordinates reader, decoder, DDR and PTS.
SRT uses the second mounted-file slot and shares SD ownership and the overlay.
```

Preserve the existing movie behavior and supported formats. This cleanup does
not introduce new codec support or change the MPEG decoder architecture.

## Keep

| Files or family | Reason |
| --- | --- |
| `MediaPlayer_av.svh` | MP2 decoder, FIFO, origin/seek timestamps, output and completion synchronization |
| `rtl/audio/mp2_decoder.sv`, `mp2_synthesis.sv`, `mp2_pcm_fifo.sv`, `mp2_pcm_output.sv`, `av_stream_fifo.sv` | Movie soundtrack path |
| `rtl/audio/mp2_cos.hex`, `mp2_window.hex`, `mp2_scale.hex` | MP2 synthesis/decoder tables |
| `rtl/mpeg2_new/` production decoder, ingress, demux, reservoir, timing and DDR modules and included fragments | MPEG movie pipeline; do not remove by names such as `probe` or `diagnostic` |
| `rtl/mpeg2_stream_fifo.sv`, `mpeg2_luma_framebuffer.sv`, `mpeg2_progressive_geometry.sv`, `mpeg2_video_720x480p.sv` | Input buffering, frame storage, geometry and output |
| `rtl/media_file_reader.sv`, `media_session_control.sv`, `media_sd_owner.sv` | File transfer, cancellation/draining, shared movie/subtitle SD transport |
| `rtl/media_seek_point.sv`, `media_seek_search.sv`, `media_seek_video_filter.sv`, `media_playback_control.sv`, `media_keyboard_control.sv` | Movie seeking, playback and keyboard transport |
| `rtl/media_duration_window.sv`, `media_duration_timeline.sv`, `media_eof_control.sv` | Movie duration, timeline qualification and final-frame/final-audio draining |
| `rtl/media_color_control.sv`, `rtl/video_config_cdc.sv` | Color selection and retained clock-domain crossings |
| `rtl/media_srt_parser.sv`, `media_subtitles.sv`, `media_subtitle_cdc.sv`, `media_subtitle_time.sv`, `media_subtitle_select.sv`, `media_subtitle_select_map.svh` | Subtitle parser, timing, menu selection and delivery |
| `MediaPlayer_subtitle_menu.svh` | Subtitle menus; remove obsolete music-mode disabling prefixes when simplifying menus |
| `rtl/media_ui_scene.sv`, `media_ui_divider.sv`, `media_player_overlay.sv`, `media_overlay_compositor.sv` | Movie transport/subtitle rendering |
| `rtl/media_overlay_font.mem`, `media_overlay_coordinates.mem`, `media_overlay_blend_rg.hex`, `media_overlay_blend_b.hex` | Retained overlay assets |
| `rtl/pll.v`, `rtl/pll/` and associated QIP files | Platform clock sources; Quartus 17 includes them through `sys/pll_q17.qip` |
| Required `sys/` framework, `audio_out`, audio PLL, I2S, S/PDIF, DAC and HPS support | Movie output and MiSTer integration |
| `tools/create_mpg.txt` | Movie preparation recipe |

Standard framework source is not a blanket deletion target. Change the custom
integration points below; preserve framework interfaces and required support.
In particular, retain two mounted-file slots (`VDNUM(2)`) for movie and SRT.

## Remove after callers are disconnected

Paths in each row are relative to the directory indicated.

| Directory | Files | Current owner |
| --- | --- | --- |
| `rtl/audio/flac/` | All eight `.sv` files: `flac_album_control`, `flac_ddr_decoder`, `flac_frame_store`, `flac_pcm_landing`, `flac_predict_mac`, `flac_stereo`, `flac_stream_decoder`, `flac_subframe` | Music include and container include |
| `rtl/audio/` | `media_music_time.sv` | Music include |
| `rtl/audio/` | `media_pcm_i2s.sv`, `media_pcm_sink.sv` | Native CD-audio output wrapper; MP2 uses its own sink |
| `rtl/` | `media_audio_visualizers.sv`, `media_waveform_visualizer.sv`, `media_audio_fft.sv`, `media_fire_renderer.sv`, `media_xy_visualizer.sv`, `media_audio_viewport.sv` | `sys/sys_top.v` music display path |
| `rtl/` | `media_fft_window.hex`, `media_fft_twiddle.hex`, `media_fft_band_end.hex` | `$readmemh` references in `media_audio_fft.sv`; not explicit entries in `files.qip` |
| `tools/` | `pack_flac_album.py`, `unpack_flac_album.py` | Standalone FLAC preparation |
| `docs/` | `FLAC.md`, `VISUALIZERS.md` | Retired feature documentation; remove current navigation links too |

Remove the matching `files.qip` entries with the modules. The music include
itself can only be deleted after extracting its retained declarations below.

## Shared files requiring edits

| File | Required separation |
| --- | --- |
| `MediaPlayer.sv` | Replace music include with retained session/file declarations, maintaining include ordering |
| `MediaPlayer_top_music.svh` | Move mounted-file buses, reader/FIFO/session signals, file size, reset edge state, movie DDR wires and EOF wiring into a movie/session include; delete music mode, album control, music CDCs and PCM producer ports |
| `MediaPlayer_top_session.svh` | Remove album restarts, seek branches, album echo handshake and album file offsets; use movie timing and seek completion; keep preflight ownership, search-tag echo, reader drain and subtitle logic |
| `MediaPlayer_top_container.svh` | Remove FLAC decoder and startup state; connect external DDR bus directly to movie arbiter signals |
| `MediaPlayer_top_clocks.svh` | Remove music startup, FIFO-consumption and MPEG-input gates; retain movie reset/prefill/backpressure and EOF handling |
| `MediaPlayer_top_framebuffer.svh` | Remove music-mode gating of quiesce and DDR response-valid; preserve real DDR busy, movie idle and outstanding-response drain |
| `MediaPlayer_top_prediction.svh` | Remove music exclusion from movie-loaded condition; retain EOF waiting for MP2 completion and final video presentation |
| `MediaPlayer_top_ports.svh` | Remove FLAC picker filter, visualizer page and status selection; make movie controls unconditional; retain existing movie/subtitle status bit positions |
| `rtl/media_duration_probe.sv` | Delete `ENABLE_FLAC`, `music_file`, FLAC magic collection/detection; retain MPEG head/tail probe and timeout/cancel drain |
| `rtl/media_ui_state.sv` | Remove track/album timing selection and six-second album sequence; preserve movie three-second activity display, seek preview, duration invalidation and session epoch |
| `sys/emu_ports.vh`, `sys/sys_top.v` emu instance | Remove `PLAYER_MUSIC`, `PLAYER_VISUALIZER`, `PLAYER_MUSIC_PAUSED`, `PLAYER_PCM_*`, `CLK_AUDIO_CD`, `PLAYER_MUSIC_FINISHED`, `PLAYER_MUSIC_ERROR`, `PLAYER_MUSIC_POSITION`; keep `PLAYER_UI_*`, `PLAYER_SUBTITLE_*` and ordinary movie audio ports |

The UI output named `album_duration_known` is misleading: it is the qualified
duration flag even in movie mode. Rename it for movie use and preserve the
`invalid_duration` guard feeding seek enablement. Do not substitute the raw
preflight `duration_valid` without preserving that behavior.

Keep the 91-bit scene-state layout initially: subtitles consume loaded bit 74
and epoch bits 90:75. A layout change is unnecessary for removing music.

## Platform output separation

### Video

`sys/sys_top.v` currently routes shadowmask output through
`media_audio_viewport`, then `media_audio_visualizers`, then the player overlay.
Remove the first two stages and their bounds/configuration CDCs. Feed overlay
RGB, HS, VS, DE and layout DE from the same movie output stage. Remove the
nine-bit viewport layout delay with the removed pipeline; leaving it would
misalign overlay geometry. Retain downstream OSD and existing output behavior.

### Audio and HDMI control

`media_native_audio` currently wraps both movie output and music output.
Reconnect the existing movie `audio_out` BCLK/LRCLK/I2S, S/PDIF and DAC signals
to their physical output consumers, with HDMI MCLK driven from the movie
audio clock. Preserve volume, filters, reset behavior and platform output muxes.

Reconnect the HPS HDMI I2C controller directly to the pad drive/readback path,
preserving open-drain semantics. Both pad assignments and HPS readback currently
pass through `native_*` wires; removing only the audio instance would break HDMI
configuration as well as sound.

After those replacements, all eight custom `rtl/platform/` modules are removal
candidates: `media_native_audio.sv`, `media_audio_clocks.sv`,
`media_audio_rate_control.sv`, `media_hdmi_audio_control.sv`,
`hdmi_audio_config.sv`, `hdmi_i2c_owner.sv`, `hdmi_i2c_write_watch.sv`, and
`i2c_register_master.sv`. Their production caller chain is the native-audio
wrapper. The rate controller starts in movie RUN mode and requests local HDMI
configuration for music handoff/recovery; movie-only startup relies on HPS
configuration. Preserve that existing movie ownership model.

Update `MediaPlayer.sdc` in the same change: remove constraints for deleted
native-audio synchronizers, reset chains, CD PLL, selector-generated clocks,
exclusive clock groups and gate crossings. Some clock-selector lookups explicitly
error if they do not resolve exactly one node. Retain unrelated movie, MP2,
overlay and platform timing constraints; recheck the resulting clock topology
when builds resume.

## Unused source candidates found during the inventory

Static source/build-reference searches found no callers for:

- `rtl/media_player.sv`: grayscale template generator, still listed in
  `files.qip` but not instantiated by the current top-level integration.
- `rtl/mycore.v`, `rtl/cos.sv`, `rtl/lfsr.v`: old template graph; `mycore`
  references the latter two, but has no caller and none are in current QIP inputs.
- `rtl/audio/audio_pcm_fifo.sv`, `audio_pcm_output_adapter.sv`,
  `audio_pcm_test_source.sv`: no production references or build entries found.
- `rtl/media_seek_diagnostics.sv` and
  `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`: unreferenced MPEG
  diagnostic helpers, outside the active build. Retain for this feature-removal
  pass because they relate to MPEG playback; revisit only as explicit dead-code cleanup.

The first three groups can be removed after a final reference check during
implementation. This static inventory is not a compiler-derived reachability
proof. `mpeg2_h262_reference_pipeline_probe_plan.sv`, for example, lacks a
standalone QIP entry but is included by `mpeg2_h262_reference_pipeline_probe_rearm.sv`
and must stay. Preserve all active decoder include fragments.

## Documentation and integration order

Update README, INSTALL, architecture, UI and build documentation to describe
the movie-only product. Remove music screenshots/current feature links; preserve
movie/subtitle documentation, release provenance and license/attribution records.
The protected `ai/core.md` still describes an all-in-one product; changing that
file requires a separate explicit user instruction under its own policy.

Implementation order:

1. Extract shared declarations and simplify core session/DDR/seek/EOF wiring.
2. Simplify duration/UI producers and remove music-facing emu ports together
   with their platform callers.
3. Rewire platform video, movie audio and HDMI I2C; update matching constraints.
4. Delete disconnected modules/assets/tools and their build references; finish
   menu and current-documentation cleanup.
5. Check remaining references/includes and run synthesis/build/timing validation
   when that phase is authorized. Playback regressions remain deferred for now.

No changes to Phosphor, repository remotes, or published artifacts are required
for this inventory. The session-wide instruction prohibits all pushes.
