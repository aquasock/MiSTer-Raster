# Building

Target: Cyclone V `5CSEBA6U23I7` (QMTech DE10-Nano-compatible MiSTer), Quartus
Prime Lite 17.0.2. The flow below is the one used to qualify every build in
[QUALIFICATION.md](QUALIFICATION.md).

## Quick start

`Raster.qsf` pins **seed 52**, the timing-qualified seed for the current source. The
Quartus project is named `Raster`, so a build writes `Raster.rbf`; copy it to a
dated `Raster_YYYYMMDD.rbf` name when packaging.

```sh
tools/build_seeds.sh /path/to/isolated-output 52       # the qualified seed
tools/build_seeds.sh /path/to/isolated-output          # seeds 52, 61 and 87
```

The script copies the tree (without `.git` or `dist/`) into one directory per seed,
sets the seed, runs `quartus_sh --flow compile Raster`, then runs the eight-corner
timing sweep on each. Results land in `timing_results.json`; bitstreams in
`seed*/output_files/Raster.rbf`. It needs `quartus_sh`, `quartus_sta` and Python 3
on `PATH`. On the current source seed 52 (+0.335 ns setup) and seed 87 (+0.064 ns)
pass every corner and seed 61 **fails** setup, so do not use 61.

## Two levels of build

**Fast sanity check** — analysis and synthesis only (elaborates and maps the design,
no placement or routing). Takes a couple of minutes. Good for catching a typo, a
missing module or a broken instantiation after a source change. It does **not**
produce a working bitstream and says nothing about timing.

**Full build** — the complete compile flow (analysis and synthesis, fit, assembler,
and the flow's own built-in timing pass), producing an actual `.rbf` and `.sof` to
run on hardware. It takes on the order of 15 to 20 minutes per seed on this target
and is what is needed before any hardware claim.

Neither level substitutes for the other: a clean fast check only proves the design
elaborates, and only a full build plus the dedicated timing pass below proves it
meets timing.

## Seeds, and why three

Quartus's fitter uses its seed as the starting point for placement search. A
different seed can produce meaningfully different placement, routing and timing
closure on the *same* source, especially on a design this close to full (block RAM
sits at about 99% utilization). The standard practice is a three-seed sweep per
candidate, then picking a seed that closes every corner rather than fixing one in
advance. It is normal for one of the three to fail a corner while another passes;
seed 61 did exactly that on the current source after passing on earlier ones.

Three settings must match for a build to reproduce a previously validated result:

- the seed value,
- ALM register-packing effort (`HIGH`), and
- the parallel-processor count used during fitting (six; `build_seeds.sh` runs
  three seeds concurrently, and changing the count can change fitter scheduling
  and is not guaranteed to reproduce identical placement).

Matching all three reproduces a **bit-for-bit identical** bitstream. This was
verified from a fresh clone; see the reproducibility note in
[QUALIFICATION.md](QUALIFICATION.md#current-build-5).

## Timing validation beyond the default flow

The compile flow's own timing analysis checks a single operating condition. Real
sign-off needs a dedicated multi-corner pass: every available operating condition
(this device's slow and fast process, voltage and temperature models), each with
setup, hold, recovery, removal and minimum-pulse-width summaries plus detailed
worst-path reports. A design can pass the default check and still fail setup or
hold at a corner it did not evaluate.

`tools/build_seeds.sh` runs this for you. To run it by hand after a full build,
from that isolated build directory:

```sh
quartus_sta -t tools/check_timing_corners.tcl
```

The script writes the summaries and worst paths to `timing_corners/`, alongside
clock, unconstrained-path and constraint checks. A successful exit means reports
were generated, not that timing passed: inspect every category at every corner and
review warnings and coverage before selecting a hardware candidate.

To sweep several already-compiled seed directories concurrently:

```sh
python3 tools/run_timing_sweep.py /path/to/isolated-build --wait-for-compile
```

It starts each seed's sweep as soon as that seed finishes compiling and writes
`timing_results.json`. Do not start a second sweep in a directory already being
analyzed. A failed seed stays in the results; select candidates only from seeds
that pass every corner.

Reading the reports: the summary reports list clocks by worst slack, worst first,
so the first data row is the number that matters. The data rows have no leading
space before the first `;`, so splitting on `;` puts the clock name in the second
field and the slack in the third, not the second.

Passing constrained timing is not complete board-I/O sign-off; the known coverage
limits are in [QUALIFICATION.md](QUALIFICATION.md#timing-coverage-and-limits).

## Known gotchas

- **Do not run the synthesis-only tool directly against the live project for a
  quick check without expecting side effects.** Doing so once made Quartus write
  several hundred lines of pin and device assignments, normally pulled in through
  the platform's own included project fragment, into the top-level project
  settings file. That is not a source change; diff the settings file before
  committing anything and revert it if it is just that side effect.
- **A killed or interrupted build leaves partial state behind** (fit database,
  incremental database, output files, the generated build-identifier file, a JTAG
  chain file). Clear it before relaunching rather than letting the next run reuse
  stale partial results.
- **The build-identifier file is regenerated on every build.** A pre-flow step
  produces it, it is not checked-in source, and it carries only a date stamp. It
  has no effect on timing or placement, but the date is embedded in the bitstream,
  so builds made on different days differ in those bytes only.

## Keeping the source tree clean

Every artifact Quartus produces (fit and incremental databases, all `output_files`
including the bitstream, `.sof` and every report, the timing-corner reports, build
logs, the generated build-identifier file, the JTAG chain file and the pin-model
dump) belongs outside the source tree. Build in an isolated copy, as
`build_seeds.sh` does, so the source directory stays pure source that is
rebuildable from scratch with nothing Quartus-generated beside it. `.gitignore`
covers that output. `.gitattributes` stores every file byte for byte: line endings
here are deliberate (the framework in `sys/` has mixed endings, and `Raster.qpf` and
`Raster.qsf` are CRLF), so do not let an editor or script normalize them.

## Resource ceiling

On-chip block RAM is the binding constraint, not logic: the current build uses 545
of 553 RAM blocks (99%) against about 79% of the ALMs. Any feature that adds block
RAM (a bigger buffer, a new decode stage, a deeper FIFO) should be budgeted against
that ceiling first; there is far more spare logic than spare RAM.

## Verification benches

The simulation benches and browser tests used during development are not part of
this repository. [QUALIFICATION.md](QUALIFICATION.md#verification-during-development)
records what they covered. Passing them never replaces hardware acceptance of a new
bitstream.
