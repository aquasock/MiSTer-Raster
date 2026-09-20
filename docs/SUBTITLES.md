# Subtitle support

SRT only, one track at a time, rendered as plain text on a shared generic
overlay compositor (the same one that draws the transport UI).
Implemented across a control/timing module (`media_subtitles`), a format
parser (`media_srt_parser`), offset/speed modules (`media_subtitle_time`/
`media_subtitle_select`), and the shared on-screen renderer
(`media_overlay_compositor`, also used by the UI — see the architecture and
UI documents for where that sits in the video chain).

## Automatic TAR association

A playlist movie automatically loads its matching SRT member by filename stem.
The user only needs **Subtitles → Visible** to enable/disable captions; the
setting persists across track changes. Movies without a matching SRT clear
previous captions. Manual **Load** remains available for the current movie.
See [TAR/M3U playlists](TAR_PLAYLIST_BOUNDARY.md) for naming and limits.

## Format: streaming SRT, no cue database

The format parser is a bounded, single-pass streaming parser — it does
**not** build an index of the whole file. It searches incoming lines for a
`HH:MM:SS,mmm --> HH:MM:SS,mmm` timestamp header, and once found, buffers
exactly the following text as one cue:

- **Two display lines maximum, 63 characters each** (`length0`/`length1`,
  7-bit fields). Text beyond that is dropped with a warning flag, not
  wrapped or truncated silently — extra source lines within one cue are
  parsed but discarded once both display slots are full.
- **Plain text only**: any `<...>` tag is stripped (angle-bracket state
  machine, `tag` flag) — nothing between `<` and `>` reaches the display,
  so there's no bold/italic/color rendering, just the stripped text.
- **Printable ASCII plus normalized "smart" punctuation**: UTF-8 lead/continuation
  byte sequences for curly single/double quotes and en/em dashes
  (`‘’’“”–—` etc.) are recognized and folded
  down to plain ASCII `'`, `"`, `-`. Any other non-printable or
  unrecognized-UTF-8 codepoint becomes `?`. Tabs become spaces.
- **Malformed cues are skipped, not fatal**: an invalid timestamp header,
  an end time that isn't after the start time, or a cue with two empty
  lines just sets a `warning` flag and the parser resumes scanning for the
  next cue — one bad entry in a file doesn't stop the rest of the track
  from working.
- Sequence numbers, blank separator lines, and any BOM/whitespace around
  them aren't validated against a specific format — the parser only cares
  about finding the timestamp line and the text that follows it.

Timestamps are converted once, with fixed-point constant multiplication
(`start_ms/end_ms * 360`, no runtime division) into the same internal time
unit playback position is tracked in.

## No whole-file index — re-scan from zero after any seek

The control module deliberately doesn't maintain a seek table into the
`.srt` file. On a seek (or a new file mount), it cancels the current reader
session and restarts the SRT parse **from byte zero**, relying on the
parser's low per-cue cost to catch back up to the new playback position
rather than tracking file offsets per cue. This keeps the design simple at
the cost of a brief re-scan window after every seek, during which the
subtitle display is suppressed until a matching cue is found (`invalidate`
forces the compositor to clear rather than show stale text).

The `.srt` file is read through the same shared SD-card reader arbiter movie
data uses — subtitle reads never get priority over, or starve, primary
playback reads; they're just another client on the same bus.

## Timing controls: offset and speed

Two independently adjustable, in-menu controls, applied to whatever cue
timestamps the parser already computed — this doesn't touch the `.srt` file,
it adjusts playback-side comparison:

- **Offset**: ±5.0 seconds, in 0.2 s menu steps (51 selectable values). The
  underlying arithmetic actually supports 0.1 s code granularity (101
  possible internal codes), but the generated menu only exposes every other
  code. A positive offset delays subtitles; a large enough positive offset
  can push a cue that starts at time zero past the "not shown yet"
  (`before_start`) boundary.
- **Speed**: 0.50x–1.50x, in 0.02x menu steps (51 selectable values), applied
  as `(elapsed - offset) * speed / 100` via a serial shift-add
  multiply/divide (no drift accumulation — computed fresh from absolute
  elapsed time every update, not integrated frame-to-frame).

Both controls use stock Main "T" pulse actions — selecting a menu row sets a
stored code rather than acting as a momentary trigger, and changing files
doesn't reset the user's chosen offset/speed (only `reset` clears them).

## Rendering: merged into the shared transport UI scene

Subtitles don't get their own dedicated text renderer or a direct path to
the screen. The control module sends parsed cue text over a small
coalescing single-in-flight command "mailbox" (toggle-bit handshake) to a
bridge that hands it to the same scene assembler that builds the transport
UI — see the UI document for the full merge/commit mechanics and the shared
renderer's double-buffering, glyph pipeline, and epoch-tagged staleness
check (a seek or file change reliably clears old subtitle text through that
same mechanism, not a subtitle-specific one). Characters are written one at
a time (up to 128: two 64-character display lines) and then finalized with
a commit carrying both line lengths and a visibility flag.

Subtitle visibility is tracked independently of the transport UI's own
show/hide timer — the two can be on screen at completely different times
within one rendered scene (see "independent visibility groups" in the UI
document). Visibility can also be toggled off entirely regardless of cue
timing via the OSD's `Visible` option, which suppresses display without
stopping the parser or timing logic underneath.

## What's not supported

- Only `.srt` — no ASS/SSA, WebVTT, VobSub, PGS, or any other subtitle
  format or embedded-in-container subtitle stream.
- No styling beyond stripped plain text: no font color, bold/italic,
  positioning cues, or karaoke-style timing within a line — all `<...>` tags
  are discarded, not interpreted.
- Hard cap of two lines / 63 characters each per cue; nothing wraps
  automatically, and overflow is dropped, not scrolled or shrunk.
- One subtitle track at a time — there's no track selection menu, just
  "load an `.srt`" for whatever's currently mounted.
- No persistent cue index, so extremely dense subtitle files pay a
  (bounded, low-cost) re-scan cost on every seek rather than an instant
  jump to the right cue.
