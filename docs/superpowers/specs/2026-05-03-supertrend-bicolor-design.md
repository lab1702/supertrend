# supertrend v0.2.0 — bicolor SuperTrend overlay design

**Date:** 2026-05-03
**Status:** Approved (brainstorming complete; ready for implementation planning)
**Builds on:** `2026-05-03-supertrend-design.md`

## Goal

Render the SuperTrend overlay with the canonical bicolor look — green when `trend == +1`, red when `trend == -1` — fulfilling the design intent that v0.1.0 deferred. The deferred attempt failed because consecutive `quantmod::addTA()` calls from one function frame do not accumulate in the chart object; only the last TA persists.

## Approach

A single `addTA()` call with a 2-column xts. quantmod recycles `col` across columns when `type = "l"`, so passing `col = c(green, red)` and a 2-column input draws each column in its own color in one TA registration. This sidesteps the chob-accumulation problem entirely.

## API

### `addSuperTrend()`

```r
addSuperTrend(n = 10, multiplier = 3,
              atr_method = c("wilder", "sma", "ema"),
              col = c("#26a69a", "#ef5350"),
              lwd = 2, on = 1)
```

- `col[1]` is the uptrend color, `col[2]` is the downtrend color.
- Defaults match TradingView (`#26a69a` / `#ef5350`).
- This is a **breaking change** versus v0.1.0's scalar `col = "#1976d2"`. Acceptable because v0.1.0 has no external users.

### `chartSuperTrend()`

Mirror the same `col` default and shape. Unchanged otherwise.

### Validation

`col` must satisfy `is.character(col) && length(col) == 2L`. A length-1 input raises an error directing users at the new length-2 contract.

`lwd` and `on` validation is unchanged from v0.1.0.

## Implementation

Internal helper, used by `addSuperTrend()` and unit-tested directly:

```r
# Returns a 2-column xts: `up` is the SuperTrend value where trend == +1
# (NA elsewhere); `down` is the SuperTrend value where trend == -1
# (NA elsewhere). Warm-up rows are NA in both columns.
split_by_trend <- function(st) { ... }
```

`addSuperTrend()` then becomes:

1. Compute `st <- SuperTrend(x, ...)`.
2. `stx <- split_by_trend(st)` (2-column xts: `up`, `down`).
3. Bind `stx` to the name `SuperTrend` in a fresh environment whose parent is `.GlobalEnv` (existing trick from v0.1.0 to satisfy `addTA`'s non-standard evaluation when called from a package namespace).
4. Build the `quantmod::addTA(SuperTrend, on = ..., type = "l", col = ..., lwd = ...)` call expression with `bquote()`, splicing in the user's `on`, `col`, `lwd`, and evaluate it in that environment.
5. `plot(ta); invisible(ta)`.

The explicit `flips → NA` masking from v0.1.0 is removed: trend masking already produces a 1-bar gap at each flip (bar `i-1` is on the up series only, bar `i` is on the down series only, and they sit on different bands), which matches the canonical TradingView look.

### Edge cases

- **All-uptrend series.** `down` column is all `NA`; `addTA` simply draws nothing for it. Same for all-downtrend.
- **Warm-up rows.** Both columns are `NA` (inherited from `SuperTrend()`'s warm-up output). No special-casing needed.
- **Single-bar trend run.** A trend that lasts exactly one bar contributes a single non-`NA` point in its color column. `lines(type = "l")` with `lwd >= 1` renders this as a visible point.

### Fallback

If quantmod turns out not to recycle `col` per column for multi-column `type = "l"` (low risk — this is a standard `matplot`-style code path, but worth verifying during implementation), fall back to a custom `newTA()` draw function with explicit per-segment line drawing.

## Testing

`tests/testthat/test-addSuperTrend.R` (extended):

- Existing smoke test (`chartSuperTrend()` renders without error on `spy_sample`, drawn to a PDF null device) keeps passing.
- `col` validation: length-1 errors, length-3 errors, non-character errors. Each with the expected message.
- `split_by_trend()` (unit-testable without rendering):
  - Returns a 2-column xts aligned to the input index, with column names `up` and `down`.
  - On every non-warmup row, exactly one of `up[i]` or `down[i]` is non-`NA`, and the non-`NA` value equals `supertrend[i]`.
  - Warm-up rows are `NA` in both columns.

No pixel/snapshot testing of rendered plots — fragile across R/graphics-device versions, same rationale as v0.1.0.

## Documentation

- Update `addSuperTrend()` and `chartSuperTrend()` roxygen `@param col` to describe the length-2 contract: `col[1]` = uptrend color, `col[2]` = downtrend color.
- Update the vignette where it references the line color, if anywhere.
- Bump `DESCRIPTION` Version to `0.2.0`.
- Add `NEWS.md` with a v0.2.0 entry: "`addSuperTrend()` and `chartSuperTrend()` now render a bicolor line (green uptrend / red downtrend) by default. Breaking change: `col` is now length-2."

## Out of scope

- Configurable line styles (lty) per trend.
- Drawing flip markers (arrows / dots) on the price panel.
- Bands shading. (All deferred — could be considered for v0.3.0.)
