# Movie transport UI

The player overlay combines the TAR playlist panel, movie time/progress and subtitles after HDMI
video processing and before the MiSTer OSD. Movie pixels, sync and layout DE
enter the compositor together.

## Menu and transport

- **Load movie or playlist** selects an `.mpg` or playlist `.tar`.
- **Subtitles** controls linked SRT visibility, offset and speed; manual Load
  is also available. Visibility persists across movies.
- **Refresh rate** and **Color matrix** control movie output. Press **A** with the
  OSD closed to switch between 4:3 and 16:9; the choice is not saved and starts
  at 4:3 after power-up.
- **Reset** and **Reset and close OSD** restart the current mounted movie or, for a
  playlist, return to its first entry; the second action also closes the OSD.

Loading, resetting and natural EOF use the existing session restart/drain
control. Movie pause and seek controls remain. For playlists, N/P selects next/previous
while the OSD is closed; EOF advances and both directions wrap. See [MPEG](MPEG.md) for playback details.

## TAR playlist panel

With a TAR playlist loaded and the MiSTer OSD closed, press **I** to show or
hide the Phosphor-style playlist panel. It shows the playlist name and up to
six movie titles, highlights the playing movie and follows **N/P**
and automatic advance. The playlist heading is centered. Long selected titles
and the playlist name scroll; the playing title moves one character every ten
output frames and pauses for 45 frames at each end, matching Phosphor. Nonplaying
rows remain stationary. Titles use the full 27-character row width; no track
numbers are drawn.
The panel remains visible across movie transitions; opening another file or
resetting the playlist closes it. Standalone MPG playback has no playlist panel.

The builder already supplies `#PLAYLIST` and `#EXTINF` display names, so existing
builder TARs work without repackaging. Plain M3U entries fall back to their
basename. Display text is bounded to 31 printable ASCII bytes per title;
unsupported bytes appear as `?`. This affects display only, not file matching.
A blanking-time formatter caches the title rows for a six-stage pixel pipeline.
The panel is centered in the HDMI output, with integer scaling at larger
resolutions. Subtitles and the time/progress display are composed above it.
The existing direct/analog output overlay limitations remain unchanged.

## State and visibility

`media_ui_state` emits the same 91-bit scene state: elapsed time, duration,
qualified duration validity, visibility, loaded state and a 16-bit epoch.
New files and seeks invalidate stale subtitle/UI scenes. Seek previews use
movie-relative targets. If presentation passes the qualified duration by more
than the existing tolerance, duration-based seeking remains disabled.

Loading or manual activity shows the overlay for three seconds. Seeking keeps
it visible; pause/seek changes refresh the countdown. Subtitles retain their
independent visibility group. Track/album timing and the six-second music
sequence have been removed.

## Scene assembly

A dedicated scene-assembler state machine, running in the video clock
domain but only advancing on every fourth pixel clock (a deliberate
multicycle timing budget — the rest of the render pipeline still runs at
full pixel rate), turns that state bus into up to 8 text regions and 4
rectangles:

- **Transport scale** uses Phosphor's native 640×480 layout, scaled by nearest
  neighbor into the largest centered 4:3 area inside the HDMI output. The bar
  and all three clocks scale together, independently of movie aspect ratio.
  Subtitle fonts retain the existing three integer sizes based on output height.
- **Time math** — HH:MM:SS for up to three fields (position, duration, and
  remaining time) — runs through one shared restoring integer divider,
  reused serially for every division the scene needs (percentage/pixel math
  included), rather than dedicated per-field arithmetic. All of the
  project's internal time values share one fixed-point tick unit (360,000
  units per second), so this is a single consistent conversion regardless of
  which timestamp is being formatted.
- **Progress bar fill** is a real proportional computation — current
  position multiplied by the bar's pixel width, divided by duration through
  that same shared divider — not a coarse or stepped indicator. Bar position, width, fill inset and clock positions are calculated in
  native 640×480 coordinates. A phase accumulator maps output pixels into
  that scene without pixel-rate division or extra video RAM. Outputs down to
  320×240 are supported by the transport coordinate mapper.
- **Subtitle content merges in as part of the same scene.** A separate
  subtitle bridge hands over subtitle text/geometry (see the subtitles
  document) through dedicated inputs on this same assembler, occupying the
  remaining two of the eight text slots plus their own background
  rectangles. The merge only proceeds once the subtitle side has finished
  writing and isn't mid-edit, and the whole assembled scene is only
  committed if *both* the playback state and the subtitle content are still
  exactly the snapshot the build started from — any change mid-build
  discards the in-progress scene and restarts from scratch rather than
  committing a torn combination of old and new content.

## Independent visibility groups

Every object (text or rectangle) carries a 1-bit group tag, and a commit
carries a 2-bit group-visibility mask alongside it — one bit for "UI
elements visible," one for "subtitle elements visible." This means the
transport UI and subtitles fade in/out **completely independently** within
the same rendered scene: the time/progress-bar overlay can finish its
3-second hide countdown and disappear while a subtitle stays on screen (or
the reverse) — they're not tied to the same visibility timer just because
they share a renderer.

## Rendering

The shared renderer (also used for subtitles) double-buffers a 12-object
scene (8 text + 4 rectangle slots, matching the assembler's output) and
only swaps to newly-committed content at a frame boundary, so nothing ever
changes mid-frame. Each pixel is resolved through a deep, fully-pipelined
per-pixel stage: parallel axis-range hit-testing against all 12 objects,
priority selection (first matching text region wins; a rectangle can be
flagged "hatched," alternating between two colors on odd/even pixel columns
rather than a single solid fill), a glyph coordinate/font ROM lookup
supporting the three integer scales, and a fixed-palette color resolve —
one color is alpha-blended (a translucent darkening of the video beneath it,
via precomputed blend ROMs rather than a runtime multiply) and the other
three are solid: opaque black text, a fixed gray, and a fixed near-white.
Every commit is additionally tagged with the same session-derived epoch
number used elsewhere in the system; a scene whose epoch doesn't match is
never displayed, which is what makes a seek or file change reliably clear
stale on-screen content instead of racing a late in-flight update.
