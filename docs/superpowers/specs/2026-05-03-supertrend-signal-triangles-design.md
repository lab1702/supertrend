# SuperTrend Signal Triangles — Design

**Date:** 2026-05-03
**Status:** Approved (pending user review of this spec)
**Target version:** supertrend 0.3.0

## Summary

Add TradingView-style buy/sell signal markers to the SuperTrend chart
overlay. On every trend flip, draw a filled triangle on the price
panel: green up-triangle below the Low of the flip-up bar, red
down-triangle above the High of the flip-down bar. Exposed both as a
standalone overlay function (`addSuperTrendSignals()`) and via a
`signals = TRUE` flag on the existing `addSuperTrend()` and
`chartSuperTrend()` entry points.

## Motivation

The package already extracts trend-flip events programmatically via
`supertrend_signals()`, but there is currently no visual rendering of
those events on the chart. TradingView's reference implementation
shows them as labeled triangles, and the package advertises itself as
TradingView-faithful (DESCRIPTION). This change closes the gap:
calling `chartSuperTrend(x)` with no extra arguments now produces a
chart that visually matches what a TradingView user would see.

## API

### New exported function

```r
addSuperTrendSignals(n = 10, multiplier = 3,
                     atr_method = c("wilder", "sma", "ema"),
                     col = c("#26a69a", "#ef5350"),
                     pch = c(24, 25),
                     cex = 1.2,
                     offset = 0.015,
                     on = 1)
```

- `n`, `multiplier`, `atr_method`: passed through to `SuperTrend()`
  (same defaults and meaning as `addSuperTrend()`).
- `col`: length-2 character vector. `col[1]` = buy marker color
  (uptrend flip), `col[2]` = sell marker color (downtrend flip).
  Defaults match the bicolor line.
- `pch`: length-2 integer vector. `pch[1]` = buy plot character,
  `pch[2]` = sell. Defaults to `c(24, 25)` (filled up- and
  down-triangles).
- `cex`: positive numeric. Marker size multiplier. Default `1.2`.
- `offset`: positive numeric. Fraction of the visible panel price
  range used to push markers off the candle (so the triangle never
  sits on top of the wick). Default `0.015` (1.5%).
- `on`: positive integer. Chart panel index. Default `1` (price
  panel — the only sensible choice).

Returns `invisible(NULL)`. Called for side effect.

Validation matches `addSuperTrend()`:
- `col` must be length-2 character with no NAs and no empty strings.
- `pch` must be length-2 integer (or coercible) with no NAs.
- `cex` and `offset` must be single positive finite numerics.
- `on` must be a single positive integer.
- Errors with a clear message if no active `chartSeries()` chart
  exists (same error path as `addSuperTrend()`).

### Modified existing functions

`addSuperTrend()` and `chartSuperTrend()` gain:

- `signals = TRUE` (logical, length 1, default `TRUE`)
- `signals_col` (defaults to `col`)
- `signals_pch` (defaults to `c(24, 25)`)
- `signals_cex` (defaults to `1.2`)
- `signals_offset` (defaults to `0.015`)

When `signals = TRUE`, after drawing the bicolor line the function
calls `addSuperTrendSignals()` with the matching arguments. When
`signals = FALSE`, behavior is identical to v0.2.1.

This is a default-on additive change. Existing v0.2.1 callers see
new triangles on their next chart redraw — no API break, no code
change required.

## Internals

### New unexported helper: `signal_markers(st, hi, lo, offset)`

Lives in a new file `R/signal_markers.R` (separate from the existing
`split_by_trend()` helper inside `addSuperTrend.R` because it's a
distinct concern and easier to test in isolation).

Inputs:
- `st`: the xts returned by `SuperTrend()` (must contain a `trend`
  column).
- `hi`, `lo`: numeric vectors of High and Low aligned to `st`.
- `offset`: positive numeric (fraction of panel range).

Behavior:
1. Compute `prev <- c(NA, head(trend, -1))`.
2. `flip_up   <- !is.na(prev) & !is.na(trend) & prev == -1 & trend == 1`
3. `flip_down <- !is.na(prev) & !is.na(trend) & prev == 1  & trend == -1`
4. `panel_range <- max(hi, na.rm = TRUE) - min(lo, na.rm = TRUE)`
5. `pad <- offset * panel_range`
6. `buy_y  <- ifelse(flip_up,   lo - pad, NA_real_)`
7. `sell_y <- ifelse(flip_down, hi + pad, NA_real_)`

Returns a list `list(buy = <xts>, sell = <xts>)` of single-column
xts aligned to `index(st)`. The buy and sell xts never have a
non-NA value in the same row (a flip is either up or down, not both).

The flip detection logic is intentionally inlined rather than calling
`supertrend_signals()` because:
1. We need `Hi`/`Lo` from the same bar to compute y-coordinates.
2. Calling `supertrend_signals()` and merging would introduce a
   second xts join for no behavioral benefit.
3. The flip computation is two lines and well-tested via the
   anchoring test below.

### Rendering

Use the same `addTA` + fresh-environment NSE pattern already
implemented in `R/addSuperTrend.R:86-113` (the in-source comment
block at lines 86-97 explains why this is necessary — quantmod's
NSE captures the call expression and re-evaluates the data symbol
at draw time, so a local variable inside a package function is not
visible).

The new function performs two `addTA` calls on the price panel
(`on = 1`):

- Buy layer: `type = "p"`, `pch = pch[1]` (default 24), `col = col[1]`,
  `bg = col[1]`, `cex = cex`, data = `parts$buy`.
- Sell layer: `type = "p"`, `pch = pch[2]` (default 25), `col = col[2]`,
  `bg = col[2]`, `cex = cex`, data = `parts$sell`.

Each `addTA` return value is then passed to `plot()` so the layer
renders from inside a function frame, mirroring the existing
behavior at `R/addSuperTrend.R:112-113`.

### Known implementation concern: `bg` forwarding

`pch = 24` and `pch = 25` are open triangles that need `bg` set to
render as filled. `quantmod::addTA(type = "p")` should forward `bg`
through to the underlying plot, but historically some quantmod
versions strip the argument. The implementation task must verify on
a real chart that the triangles render filled (not as open outlines).

If `bg` is stripped, the fallback is to use `pch = 17` (already-filled
triangle up) and `pch = 25` with `col` only. The visual outcome is
identical: filled green up-triangle, filled red down-triangle. The
default `pch` would change to `c(17, 25)` if needed, but a single
filled triangle pair (matched-fill) is the only requirement. Pick
whichever pair quantmod renders correctly and document the choice in
NEWS.md.

## Testing

New file: `tests/testthat/test-signals-overlay.R`.

Cases:

1. `signal_markers()` returns a list with named elements `buy` and
   `sell`, each an xts aligned to the input index with a single
   column.
2. On `spy_sample`: count of non-NA values in `buy` equals
   `sum(supertrend_signals(st)[, "long_entry"])`. Same for `sell`
   vs. `short_entry`. This anchors the new helper to the existing
   tested signal logic.
3. Marker y-values: on flip-up bars, `buy[i] == lo[i] - pad`; on
   flip-down bars, `sell[i] == hi[i] + pad`; NA elsewhere.
4. Warm-up rows (where `trend` is NA) produce NA in both buy and
   sell.
5. `buy` and `sell` never share a non-NA row.
6. `addSuperTrendSignals()` validation: bad `col` length, non-finite
   or non-positive `cex`, non-finite or non-positive `offset`, bad
   `pch` length, bad `on`. Each errors with the expected message.
7. `addSuperTrendSignals()` errors with the standard message when no
   active chart exists.

Pixel output is intentionally not snapshotted — quantmod overlays
are not amenable to image snapshots and the existing test suite
follows this convention. The flip-count anchor test (case 2) is the
primary correctness guard; it ties this overlay's events to the
already-validated `supertrend_signals()` output.

## Documentation updates

- New `man/addSuperTrendSignals.Rd` generated from roxygen on the
  new function. Example wrapped in `if (interactive()) { ... }` per
  the v0.2.1 convention.
- Update `man/addSuperTrend.Rd` and `man/chartSuperTrend.Rd` for the
  new `signals*` arguments. Brief mention in the description that
  signal triangles now render by default.
- `NAMESPACE`: add `export(addSuperTrendSignals)`.
- `README.md`: short note in the chart section that flips render as
  triangles and that `signals = FALSE` reverts to the v0.2.1 line-only
  look.
- `NEWS.md`: new `# supertrend 0.3.0` heading describing the
  additive change. Note any `pch` fallback used (see implementation
  concern above).
- `DESCRIPTION`: bump `Version: 0.3.0`.

## Out of scope (YAGNI)

- Per-flip text labels (e.g., "BUY" / "SELL" beside the triangles).
  TradingView shows them; we do not, to keep the chart uncluttered.
  Can be added in a follow-up if requested.
- Per-event marker shapes beyond the length-2 `pch` vector.
- Wiring marker rendering into `supertrend_signals()` output
  directly — the helper takes the raw `SuperTrend()` xts so it can
  be reused without recomputing flips from scratch elsewhere.
- Snapshot/pixel tests of the rendered chart.

## Files touched

- `R/signal_markers.R` (new) — internal helper.
- `R/addSuperTrendSignals.R` (new) — exported overlay function.
- `R/addSuperTrend.R` — add `signals*` arguments and call-through.
- `R/chartSuperTrend.R` — add `signals*` arguments and pass-through
  to `addSuperTrend()`.
- `NAMESPACE` — add export (regenerated by roxygen).
- `man/addSuperTrendSignals.Rd` (new) — regenerated by roxygen.
- `man/addSuperTrend.Rd`, `man/chartSuperTrend.Rd` — regenerated by
  roxygen.
- `tests/testthat/test-signals-overlay.R` (new).
- `README.md` — short note.
- `NEWS.md` — new version section.
- `DESCRIPTION` — version bump.
