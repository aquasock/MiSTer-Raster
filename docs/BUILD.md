# Building

The historical resource figures below predate the movie-only cleanup. Its
accepted build is documented in [baseline results](RASTER_BUILD_RESULTS.md).
The playlist candidate has its own [build results](RASTER_PLAYLIST_BUILD_RESULTS.md);
hardware acceptance must be established separately for each candidate.

Target: Cyclone V `5CSEBA6U23I7` (QMTech DE10-Nano-compatible MiSTer),
Quartus Prime 17.0.2 Lite. This covers the actual build flow used to
validate the source in this tree — not aspirational, every step here has
been run and its output verified.

## Two levels of build

**Fast sanity check** — analysis & synthesis only (elaborates and maps the
design, no placement/routing). Takes a couple of minutes. Good for catching
a typo, a missing module, or a broken instantiation after a source change,
before committing to a full build. It does **not** produce a working
bitstream and tells you nothing about timing.

**Full build** — the complete compile flow (analysis & synthesis → fit →
assembler → the flow's own built-in timing pass), producing an actual
`.rbf`/`.sof` you can run on hardware. Takes on the order of 15–20 minutes
per seed on this target. This is what's needed before any hardware claim.

Neither level substitutes for the other — a clean fast-check only proves the
design elaborates; only a full build (plus the dedicated timing pass below)
proves it actually meets timing.

## Seeds, and why three

Quartus's fitter uses its seed as the starting point for placement search —
a different seed can produce meaningfully different placement, routing, and
therefore different timing closure on the *same* source, especially on a
design this close to full on this device (the tightest resource, on-chip
block RAM, regularly sits around 99% utilized). The project's standard
practice is a three-seed sweep per candidate commit, then picking whichever
seed(s) actually close timing rather than committing to a single seed in
advance. There's no guarantee any given seed passes — it's normal for one or
two of the three to fail a corner while another passes cleanly.

Three settings must match for a build to be a **faithful reproduction** of
a previously-validated result, not just "the same source":

- the seed value itself,
- ALM register-packing effort (the project's standard builds use the `HIGH`
  setting), and
- the parallel-processor count used during fitting (the project's
  multi-seed builds constrain each concurrent build to a fixed thread count
  so three seeds sharing one machine don't starve each other — a value tied
  to the host machine's core count more than the design, but changing it
  can change fitter thread scheduling and isn't guaranteed to reproduce
  identical placement).

Verified directly in this session: matching all three against a previously
validated build reproduced a **bit-for-bit identical** output bitstream
(matching SHA-256), not just matching resource/timing numbers — so this
reproducibility claim isn't theoretical.

## Qualified seed and one-command build

`Raster.qsf` pins **seed 52**, the timing-qualified seed. Measured on the current
source (all eight corners, zero total negative slack): seed 52 setup +0.335 ns,
seed 87 +0.064 ns, and seed 61 **fails** setup at -0.199 ns. Seed 52 was rebuilt
after the project and source-file renames and produced a byte-identical bitstream;
seeds 61 and 87 were measured before the renames. Do not use seed 61.

The Quartus project is named `Raster`, so a build writes `Raster.rbf`. Copy it to a
dated `Raster_YYYYMMDD.rbf` name when packaging. To reproduce the three-seed flow
below from a clean checkout in one step:

```sh
tools/build_seeds.sh /path/to/isolated-output          # seeds 52 61 87
tools/build_seeds.sh /path/to/isolated-output 52       # just seed 52
```

It copies the tree (without `.git` or `dist/`) into one directory per seed, sets the
seed, runs `quartus_sh --flow compile Raster`, then runs the eight-corner timing
sweep. Results land in `timing_results.json`; bitstreams in `seed*/output_files/`.

## Timing validation beyond the default flow

The full compile flow's own built-in timing analysis checks one operating
condition. Real sign-off needs a dedicated multi-corner pass afterward —
enumerating every available operating condition (this device's slow and
fast process/voltage/temperature models) and, for each one, producing setup,
hold, recovery, removal, and minimum-pulse-width summaries plus detailed
worst-path reports. A design can pass the default flow's check and still
fail setup or hold on a corner that check didn't evaluate — the corner sweep
is what actually proves timing closure, not the flow's own pass/fail.

Reading those reports: the summary reports list clocks by worst slack,
sorted worst-first — the first data row is the number that matters. A small
formatting trap worth knowing: these report tables have no leading space
before the first `;` delimiter on each data row, which shifts naive
column-splitting off by one field if you parse them by splitting on `;` —
the clock name is the second field, the slack value is the third, not the
second.

### Parallel seed timing sweeps

Per owner instruction on 2026-09-19, run the dedicated timing sweeps for the
isolated seed directories concurrently. Each seed still enumerates all eight
corners and all five timing categories. From the source tree:

```sh
python3 tools/run_timing_sweep.py /path/to/isolated-build --wait-for-compile
```

This starts each seed's sweep as soon as that seed finishes compilation,
collects every result, and writes `timing_results.json`. Do not start a second
sweep in a directory already being analyzed. A failed seed remains in the
results; select hardware candidates only from seeds passing every corner.

## Known gotchas (hit and worked around in this session)

- **Don't run the synthesis-only tool directly against the live project
  for a "quick check" without expecting side effects.** Doing so once
  caused Quartus to write several hundred lines of pin/device assignments
  — normally pulled in indirectly through the platform's own included
  project fragment — directly into the top-level project settings file.
  That's not a source change; if it happens, diff the settings file before
  committing anything and revert it if it's just that side effect.
- **A killed/interrupted build leaves partial state behind** (fit database,
  incremental database, output files, a generated build-identifier file, a
  JTAG chain file) that should be cleared before relaunching, rather than
  letting the next run silently reuse stale partial results.
- **The build-identifier file is regenerated fresh on every build** (it's
  produced by a pre-flow step, not checked-in source) and carries only a
  date stamp — it has zero effect on timing or placement, unlike the seed
  and packing/thread settings above which do.

## Keeping the source tree clean

Every artifact Quartus produces — the fit/incremental databases, all
`output_files` (bitstream, `.sof`, and every `.rpt`/`.summary`/`.smsg`
report), the dedicated timing-corner reports, build/compile logs, the
generated build-identifier file, the JTAG chain file, and the pin-model
dump — belongs outside the source tree, not mixed into it. Building
in-place and then sweeping every newly-created file/directory into a
separate output location afterward keeps the source directory exactly what
it should be: pure source, rebuildable from scratch, with nothing
Quartus-generated checked in alongside it.

## Resource ceiling

On this device, on-chip block RAM is the binding constraint, not logic —
recent builds sit around 99% RAM-block utilization against roughly 85% ALM
utilization. Any future feature that adds block RAM (a bigger buffer, a
new decode stage, a deeper FIFO) should budget against the RAM
ceiling first; there's very little headroom left there even though there's
comparatively much more spare logic capacity.

## Movie-only timing report command

After a full build, run from that isolated build directory:

```sh
quartus_sta -t tools/check_timing_corners.tcl
```

The script enumerates all available operating conditions and writes setup,
hold, recovery, removal and minimum-pulse-width summaries and worst paths to
`timing_corners/`, alongside clock, unconstrained-path and constraint checks.
A successful script exit means reports were generated, not that timing passed.
Inspect every category at every corner and review warnings/coverage before
selecting a hardware candidate.

### Playlist and fixed 4:3 transport rendering

Run `python3 tools/verify_movie_playlist_ui.py` for metadata, key lifecycle,
centered heading glyphs and a complete playing-title scroll cycle. Run
`python3 tools/verify_progress_scaling.py` for exact transport pixels at five
output sizes and per-pixel coordinate checks through six output mode changes.
These checks do not replace hardware acceptance of a new bitstream.
