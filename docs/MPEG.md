# MPEG-2 / H.262 video, and MP2 movie audio

The movie playback path — video and audio both, since both are demuxed from
the same Program Stream (see the architecture document for how the container
demux splits them). Video is H.262; normative basis for that part is ITU-T
H.262 (02/2000) / ISO/IEC 13818-2:2000 and, for presentation timing units,
ITU-T H.222.0 / ISO/IEC 13818-1 (33-bit PTS at the 90 kHz systems-layer
timebase). Movie audio remains part of the same playback session.

## Design principle: syntax validity vs. implementation capability

The header parser is explicit about a deliberate separation, worth stating
up front because it shapes everything else here: **a stream can be
completely valid H.262 and still be outside what this decoder currently
implements — that's a capability restriction, not a syntax error.** Only
genuine bitstream violations (a reserved code value, a marker bit that isn't
1, an I-picture after a GOP header that isn't actually coded as I, and
similar) set the syntax-error condition, which the parser reports with a
stable numbered source (21 distinct, individually identified violation
sites) rather than one generic "bad stream" flag. Content using a feature
this decoder hasn't implemented yet is tracked through separate
capability-boundary signals instead of being misreported as corrupt.

## Accepted profile

Checked from the sequence/picture headers themselves, not asserted from the
filename or container:

- **Progressive only.** Both `progressive_sequence` (sequence extension) and
  `progressive_frame` (picture coding extension) must be set, and
  `picture_structure` must indicate a full frame picture (not top/bottom
  field) with `frame_pred_frame_dct` also set. Interlaced content — field
  pictures, field DCT, 3:2 pulldown fields — is outside the accepted profile
  even though the parser recognizes and captures the relevant syntax
  elements (`top_field_first`, `repeat_first_field`) for a future decoder.
- **4:2:0 chroma only** (`chroma_format == 01`); 4:2:2 and 4:4:4 are valid
  H.262 chroma formats but unsupported here, and the frontend additionally
  cross-checks that `chroma_420_type` in the picture coding extension
  actually agrees with `progressive_frame` when chroma format is 4:2:0, per
  spec semantics — a real syntax check, not a capability gate.
- **Resolution capped at 720×480** (both dimensions non-zero and within
  that bound) — the geometry check gating reconstruction downstream of the
  header parse.
- **Frame rate must be one of H.262 Table 6-4's eight direct rates**
  (23.976, 24, 25, 29.97, 30, 50, 59.94, 60) with no rational
  `frame_rate_extension_n/d` scaling. A non-direct rate is syntactically
  legal H.262 but isn't rationally scaled by the current presentation-timing
  scheduler, so it's tracked as an unsupported-timing condition rather than
  producing a wrong presentation time.
- **No concealment motion vectors, no scalable-extension streams.** Both are
  valid H.262 features explicitly excluded from the current implementation.
- **Default intra quantization matrix only.** A downloaded (non-default)
  quantization matrix is valid H.262; the inverse-quantization stage is
  explicitly built around the normative default matrix as a tracked
  capability boundary rather than general matrix-download support.
- I-picture syntax additionally requires all four motion-vector `f_code`
  fields to read as the "not present" value (`1111`), matching an I-picture
  genuinely carrying no motion vectors — this is itself a real H.262
  semantic requirement (checked as a syntax error, not a capability
  restriction) given `concealment_motion_vectors` is unsupported.

## Decode pipeline

**Header/syntax parsing** extracts sequence and picture-level parameters
(the profile fields above, plus aspect ratio, colour description/matrix
coefficients, quantization-matrix state) directly from start-code-delimited
payload bytes, byte-window matched against the H.262 start-code table.

**Slice/macroblock syntax and DCT coefficient parsing** runs as a dedicated
per-picture parser layered on top of the header stage, driving inverse
quantization and the shared IDCT engine. One shared IDCT engine — not
separate per-picture-type datapaths — serves I, P, and B reconstruction
alike; this sharing is enforced by an explicit audit in the project's timing
analysis tooling (checking exactly one physical IDCT hierarchy with all
index bits present), not left as an informal convention.

**P-picture prediction** is a separate, purpose-built path layered
alongside the main syntax parser: it reconstructs inter-coded macroblocks
from motion vectors, residual coefficients, and reference-frame pixels
fetched back out of DDR, then writes the result through the same
destination-store client the intra path uses (muxed by which source
produced the current block). A destination-ownership handshake at the top
level specifically prevents a following P-picture's input from overtaking a
reference frame bank that's still on screen — hand-rolled control logic
outside any single decode module, not implicit in the store itself.

**B-picture handling** is the most involved stage: a dedicated presentation
scheduler owns display-order reordering, allocates alternating decode/display
scratch banks for the two frames a B-picture references, and runs the full
publish/present state machine gated by a 2-vblank handshake so a
reconstructing B-picture never displaces the future reference frame it still
needs. Every accepted picture header produces an explicit classification
event, so two adjacent B pictures can't collapse into a single coding-type
decision — each is tracked and scheduled independently.

## Timestamps and presentation

Because the current input has no H.222.0 PES layer to source a normative
PTS from, presentation timing is synthesized locally at the picture-header
boundary using the same 33-bit/90 kHz representation a real PES PTS would
use — chosen specifically so a future PES demux could supply real
timestamps without changing anything downstream. Internally, cumulative time
is tracked in quarter-ticks (not whole 90 kHz ticks) specifically because
two of the eight direct H.262 frame rates have fractional 90 kHz periods
(24000/1001 and 60000/1001); quarter-tick accumulation represents every
direct rate's frame period exactly rather than accumulating long-term
rounding drift. A monotonically-advancing check flags a timing regression as
an error condition once enough pictures have been observed to prove forward
progress should already be occurring.

Reconstructed pictures are bound to their timestamp and carried through
B-picture reordering by frame-bank identity, so display order (not decode
order) is what actually reaches the screen.

## DDR usage

Reconstruction, reference reads, and prediction writes all go through one
four-client arbiter (picture-store writer, framebuffer-scanout reader,
P/B reference-prediction reads, and the compressed-video stream client;
see the architecture document for the platform-level arbitration layer). The
compressed-video ingress itself sits in an 8 MiB DDR ring ahead of the
framebuffer regions, holding one compressed byte (plus optional PTS/EOF tag)
per word.

## MP2 audio decode

Movie audio is MPEG-1 Layer II — a completely separate decoder from the
video pipeline above, sharing only the same demuxed byte-stream source.
Worth noting up front: unlike the video pipeline, **this decoder never
touches DDR at all** — its entire working state (one frame buffer plus the
polyphase synthesis filter's history) lives in on-chip RAM, decoded fully
serially, one frame at a time, with no HPS software or soft CPU assisting
it.

**Accepted profile**, checked from the frame header itself: 48 kHz only
(the other two MPEG-1 sample rates are rejected), stereo/dual-channel/joint-stereo
only (the mode field's mono encoding is explicitly rejected), and bitrates from 112–384 kb/s only — the lower
half of the Layer II bitrate table (32–96 kb/s, generally associated with
lower-quality or mono content) is out of scope. **CRC-protected frames are
rejected outright**, not decoded-with-unchecked-CRC — the header's
copyright-protection bit must indicate no CRC is present, since CRC
verification itself isn't implemented.

**Decode stages**, standard Layer II subband coding: per-subband/channel
bit allocation (from one of three allocation tables depending on subband
range), scale-factor-select info governing how each subband's up to three
scale factors are shared or individually transmitted across the frame's
three granules, the scale factors themselves, then the actual quantized
samples — including un-grouping for the three low-resolution quantizer
levels (3/5/9-level) that pack three samples into one transmitted codeword,
requiring integer division to unpack. Joint-stereo mode additionally
computes a coupling boundary subband from the header's mode-extension bits,
above which the two channels share one allocation/scale-factor/sample set
(intensity stereo) rather than being coded independently.

**Synthesis** is the standard 32-subband polyphase filter: a serial
(one-MAC-per-cycle) matrix multiply against a cosine table followed by a
windowed accumulation against a 512-tap window table, both loaded from
precomputed ROMs, maintaining a rolling history buffer sized for the
standard 64-slot polyphase window. This runs three times per decoded frame
(once per granule), producing the 3×12 = 36 output sample pairs a Layer II
frame carries, and its output is rounded (not truncated) and clamped to
16-bit PCM.

**Frame-sync recovery**: starting mid-stream (typically right after a seek
lands somewhere that isn't exactly a frame boundary) can optionally search
forward for a valid sync pattern and then verify it by confirming the
*next* header also lands correctly at the declared frame length before
trusting it — a lookahead check specifically to reject an accidental sync
pattern occurring inside arbitrary compressed data rather than a real frame
boundary.

**Timestamps and output** run through a separate stage from the decoder
itself: it anchors to a one-shot origin PTS, then free-runs its own
internal clock at the audio sample rate rather than re-deriving position
from every incoming timestamp, comparing each frame's embedded PTS against
that free-running clock only to detect drift. Small embedded-timestamp
jitter (documented against real captured test material showing PES
timestamps jittering backward by a fraction of a millisecond at certain
points) is tolerated up to a fixed threshold without any correction —
samples are never dropped or the clock rebased to chase it; only jitter
beyond that threshold raises a flag. An empty source at a scheduled sample
tick is a genuine underrun (flagged, output goes silent) rather than
stalling. Seeking has two independent coarse/fine layers: the decoder
itself can discard whole frames that land well before a seek target
(keeping roughly one frame of preroll rather than decoding-then-discarding
every sample), while the output stage separately fast-forwards through
already-decoded samples up to the target position.

## Menu-exposed settings

Three OSD options directly affect this pipeline (see the UI document for
where these sit in the overall menu structure):

- **Aspect ratio** (4:3 / 16:9) sets the display-shape hint sent to the
  platform scaler outright. This is a user override, not a stream-detected
  value — the sequence header's own `aspect_ratio_information` field is
  parsed (see "Header/syntax parsing" above) but never used to set this;
  the menu selection is the only source of truth for display shape.
- **Refresh rate** (59.94 Hz / 50 Hz) switches the raster generator between
  NTSC-style (525 total lines) and PAL-style (625 total lines) output
  timing, and also feeds the B-picture presentation scheduler's cadence
  logic — frame pacing for pulldown/repeat behavior is aware of which
  output rate is actually selected, not fixed to one assumption.
- **Color matrix** (Auto / BT.601 / BT.709) selects the RGB conversion
  matrix applied ahead of the framebuffer. Auto uses whichever matrix the
  stream itself signaled (resolved per-frame in the picture-color stage
  described in "Header/syntax parsing" above); BT.601/BT.709 force that
  choice regardless of what the stream says. The selection and the
  currently-decoded frame's own signaled value cross independently into the
  video clock domain and only commit together at the first pixel of the
  next frame, so changing this setting — or a new stream signaling a
  different matrix — never produces a mid-frame color seam.

## What's explicitly rejected as out-of-capability (not corrupt)

All of the following are syntactically valid H.262 that this decoder
deliberately doesn't decode yet — reported as unsupported/incomplete
capability, never mislabeled as a corrupt stream:

- Interlaced/field-structured pictures and field DCT.
- Any chroma format other than 4:2:0.
- Resolutions above 720×480.
- Frame rates using the rational `frame_rate_extension_n/d` scaling instead
  of one of the eight direct Table 6-4 rates.
- Concealment motion vectors.
- Scalable-extension (layered) streams.
- A downloaded (non-default) intra quantization matrix.

## What's a genuine syntax error

By contrast, these are real H.262 violations, not capability limits — 21
individually-identified conditions including (non-exhaustive): a
sequence/picture-coding extension not immediately following its header as
H.262 requires, an unmarked marker bit, a reserved chroma-format or
picture-structure code value, an `f_code` value outside its valid range, the
first coded picture after a GOP header not actually being an I-picture, and
a progressive-sequence stream whose picture-coding extension doesn't
actually assert frame structure/frame-pred-frame-DCT.
