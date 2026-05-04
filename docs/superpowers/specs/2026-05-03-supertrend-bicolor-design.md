# supertrend v0.2.0 — bicolor SuperTrend overlay design

**Date:** 2026-05-03
**Status:** Approved (brainstorming complete; ready for implementation planning)
**Builds on:** `2026-05-03-supertrend-design.md`

## Goal

Render the SuperTrend overlay with the canonical bicolor look — green when `trend == +1`, red when `trend == -1` — fulfilling the design intent that v0.1.0 deferred. The deferred attempt failed because consecutive `quantmod::addTA()` calls from one function frame do not accumulate in the chart object; only the last TA persists.

## Approach

Two single-column `addTA()` calls — one for the uptrend mask (`col[1]`), one for the downtrend mask (`col[2]`) — both made via the existing eval-in-env wrapper from a fresh environment whose parent is `.GlobalEnv`. After each `addTA` returns, call `plot()` on the resulting `chobTA`. Both layers accumulate in the chob and render in their respective colors.

### Why two calls (and not one multi-column call)

quantmod's `chartTA` (the renderer behind `addTA`) iterates per-column parameters using a diagonal index `pars$col[[cols]][[cols]]`. For a flat character vector `col = c("green", "red")` and a 2-column xts, this expression errors out on the second column (`"#ef5350"[[2]]`), so the apparent shortcut "pass a 2-col xts and a length-2 col vector" does not work in practice — the user gets `Error: TA parameter length must equal number of columns`.

### Why this works now (v0.1.0 deferral was correct at the time but obsolete)

The v0.1.0 commit message attributed the bicolor failure to "consecutive `quantmod::addTA` calls from inside one function frame don't accumulate in the chob — only the last TA persists." Reading `quantmod:::skeleton.TA` confirms why: when `addTA` is called from inside a function frame, it returns the `chobTA` object without mutating or redrawing the chob. v0.1.0's two-call attempt apparently never invoked `plot()` on the returned objects, so the layers were dropped on the floor. v0.1.0 then rewrote the code to use a single `addTA` + `plot()` pattern (via the eval-in-env workaround) for the simple monocolor case.

Today's eval-in-env wrapper plus an explicit `plot()` on each returned `chobTA` makes the two-call pattern work correctly. Verified by running it from a function frame and counting line strokes in the output PDF.

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
# Returns a list with two single-column xts elements: `up` carries the
# SuperTrend value where trend == +1 (NA elsewhere); `down` carries it
# where trend == -1 (NA elsewhere). Warm-up rows are NA in both.
split_by_trend <- function(st) { ... }
```

The helper returns two **separate** xts (not one 2-column xts) because the rendering path uses two single-column `addTA` calls, not one multi-column call.

`addSuperTrend()` then becomes:

1. Compute `st <- SuperTrend(x, ...)`.
2. `parts <- split_by_trend(st)` — list with `parts$up` and `parts$down`.
3. Create a fresh environment whose parent is `.GlobalEnv`. Bind `parts$up` to the name `up_line` and `parts$down` to `down_line` in that environment. (This is the existing v0.1.0 trick to satisfy `addTA`'s non-standard evaluation when called from a package namespace.)
4. Build two `quantmod::addTA(..., type = "l", lwd = ...)` call expressions with `bquote()` — one referencing `up_line` with `col = col[1]`, one referencing `down_line` with `col = col[2]` — and evaluate each in that environment. Save the two returned `chobTA` objects.
5. `plot()` each in turn (`plot(ta_up); plot(ta_down)`).
6. Return `invisible(NULL)` (no single TA object to hand back).

The explicit `flips → NA` masking from v0.1.0 is removed: trend masking already produces a visual break at each flip (the up series ends at the last `+1` bar, the down series begins at the first `-1` bar, and they sit on different bands).

### Edge cases

- **All-uptrend series.** `parts$down` is all `NA`; `lines()` draws nothing for it. The `addTA` + `plot()` call still runs cleanly. Same for all-downtrend.
- **Warm-up rows.** Both `parts$up` and `parts$down` are `NA` (inherited from `SuperTrend()`'s warm-up output). No special-casing needed.
- **Single-bar trend run.** A trend that lasts exactly one bar contributes a single non-`NA` point in its color column with no adjacent non-`NA` neighbor in the same series, so `lines(type = "l")` draws nothing for that bar (a stroke needs two adjacent points). Acceptable: SuperTrend rarely produces single-bar regimes, and a single missing pixel between visible green/red segments is not a usability issue.

## Testing

`tests/testthat/test-addSuperTrend.R` (extended):

- Existing smoke test (`chartSuperTrend()` renders without error on `spy_sample`, drawn to a PDF null device) keeps passing.
- `col` validation: length-1 errors, length-3 errors, non-character errors. Each with the expected message.
- `split_by_trend()` (unit-testable without rendering):
  - Returns a list with two named elements `up` and `down`, each a single-column xts aligned to the input index.
  - On every non-warmup row, exactly one of `up[i]` or `down[i]` is non-`NA`, and the non-`NA` value equals `supertrend[i]`.
  - Warm-up rows are `NA` in both elements.

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
