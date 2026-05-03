# supertrend v0.2.0 — Bicolor Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render `addSuperTrend()` / `chartSuperTrend()` in two colors — green when `trend == +1`, red when `trend == -1` — replacing v0.1.0's single-color line.

**Architecture:** Build a 2-column xts (`up` = SuperTrend value where `trend == +1`, `NA` elsewhere; `down` = the inverse) and pass it to a single `quantmod::addTA(..., type = "l", col = c(green, red))` call. quantmod recycles `col` across columns, so one TA registration draws both. This sidesteps the chob-accumulation problem that blocked the two-`addTA`-call approach in v0.1.0. The eval-in-env trick from v0.1.0 (which bypasses `addTA`'s NSE from a package namespace) is preserved.

**Tech Stack:** R, xts, zoo, quantmod, TTR, testthat (edition 3), roxygen2.

**Spec:** `docs/superpowers/specs/2026-05-03-supertrend-bicolor-design.md`

---

### Task 0: De-risk the col-recycling assumption

The whole plan hinges on quantmod recycling `col` across the columns of a multi-column xts when `type = "l"`. Verify this BEFORE writing any code. If it doesn't recycle, stop and report — the fallback (custom `newTA()` draw function) needs a different plan.

**Files:**
- Create: `/tmp/verify-addta-col.R` (throwaway)

- [ ] **Step 1: Write the verification script**

Create `/tmp/verify-addta-col.R`:

```r
# Verify that quantmod::addTA recycles `col` across columns of a
# multi-column xts when type = "l". If yes, the bicolor plan works.
suppressPackageStartupMessages({
  library(xts)
  library(quantmod)
})

# Build a tiny synthetic OHLC and a 2-column overlay where the two
# columns are obviously visible (different y-values) and only one is
# non-NA per row (so each color owns half the bars).
n <- 40
dates <- as.Date("2025-01-01") + seq_len(n) - 1L
close <- 100 + sin(seq_len(n) / 3)
ohlc <- xts(cbind(Open = close, High = close + 0.5,
                  Low = close - 0.5, Close = close),
            order.by = dates)

up   <- ifelse(seq_len(n) %% 2L == 0L, close + 1, NA_real_)
down <- ifelse(seq_len(n) %% 2L == 1L, close - 1, NA_real_)
overlay <- xts(cbind(up = up, down = down), order.by = dates)

pdf("/tmp/verify-addta-col.pdf", width = 8, height = 5)
chartSeries(ohlc, theme = "white", name = "col-recycling check")
ta <- addTA(overlay, on = 1, type = "l",
            col = c("#26a69a", "#ef5350"), lwd = 2)
plot(ta)
dev.off()

cat("addTA call returned without error.\n")
cat("Inspect /tmp/verify-addta-col.pdf — the up dots should be\n",
    "GREEN and the down dots RED. If both are the same color,\n",
    "quantmod is NOT recycling col and the plan needs the fallback.\n",
    sep = "")
```

- [ ] **Step 2: Run it**

Run: `Rscript /tmp/verify-addta-col.R`
Expected: prints "addTA call returned without error." and writes `/tmp/verify-addta-col.pdf`.

- [ ] **Step 3: Inspect the PDF**

Open `/tmp/verify-addta-col.pdf`. The `up` series should be green (`#26a69a`), `down` series red (`#ef5350`). If both are the same color, **STOP** and report — the col-recycling assumption is wrong; the fallback approach (custom `newTA()` with explicit per-segment drawing) is needed and the rest of this plan does not apply.

If colors differ, proceed.

- [ ] **Step 4: No commit**

This is a throwaway verification. Delete `/tmp/verify-addta-col.R` and `/tmp/verify-addta-col.pdf` once satisfied.

---

### Task 1: Add `split_by_trend()` internal helper (TDD)

Pure data-transform function. Takes the xts that `SuperTrend()` returns and produces the 2-column `up` / `down` xts that `addSuperTrend()` will hand to `addTA`. Internal (not exported), unit-testable without rendering.

**Files:**
- Modify: `R/addSuperTrend.R` (add `split_by_trend()` near the top, above `addSuperTrend()`)
- Create: `tests/testthat/test-split-by-trend.R`

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-split-by-trend.R`:

```r
test_that("split_by_trend returns a 2-column xts named up/down", {
  hlc <- make_mixed_hlc()
  st <- SuperTrend(hlc, n = 10, multiplier = 3)

  out <- supertrend:::split_by_trend(st)

  expect_true(xts::is.xts(out))
  expect_equal(ncol(out), 2L)
  expect_equal(colnames(out), c("up", "down"))
  expect_equal(zoo::index(out), zoo::index(st))
})

test_that("split_by_trend masks supertrend by trend direction", {
  hlc <- make_mixed_hlc()
  st <- SuperTrend(hlc, n = 10, multiplier = 3)
  out <- supertrend:::split_by_trend(st)

  trend <- as.numeric(st[, "trend"])
  supertrend_vals <- as.numeric(st[, "supertrend"])
  up <- as.numeric(out[, "up"])
  down <- as.numeric(out[, "down"])

  # Where trend == +1: up == supertrend, down == NA
  up_rows <- which(trend == 1)
  expect_equal(up[up_rows], supertrend_vals[up_rows])
  expect_true(all(is.na(down[up_rows])))

  # Where trend == -1: down == supertrend, up == NA
  down_rows <- which(trend == -1)
  expect_equal(down[down_rows], supertrend_vals[down_rows])
  expect_true(all(is.na(up[down_rows])))
})

test_that("split_by_trend leaves warm-up rows NA in both columns", {
  hlc <- make_mixed_hlc()
  st <- SuperTrend(hlc, n = 10, multiplier = 3)
  out <- supertrend:::split_by_trend(st)

  trend <- as.numeric(st[, "trend"])
  warmup_rows <- which(is.na(trend))
  expect_true(length(warmup_rows) > 0L)
  expect_true(all(is.na(out[warmup_rows, "up"])))
  expect_true(all(is.na(out[warmup_rows, "down"])))
})

test_that("split_by_trend handles all-uptrend series", {
  hlc <- make_monotonic_up_hlc(n = 40)
  st <- SuperTrend(hlc, n = 10, multiplier = 3)
  out <- supertrend:::split_by_trend(st)

  trend <- as.numeric(st[, "trend"])
  expect_true(all(trend[!is.na(trend)] == 1L))
  # All non-warmup rows in `up`, all NA in `down`
  expect_true(all(is.na(as.numeric(out[, "down"]))))
  non_warmup <- which(!is.na(trend))
  expect_equal(as.numeric(out[non_warmup, "up"]),
               as.numeric(st[non_warmup, "supertrend"]))
})

test_that("split_by_trend never has both columns non-NA in the same row", {
  hlc <- make_mixed_hlc()
  st <- SuperTrend(hlc, n = 10, multiplier = 3)
  out <- supertrend:::split_by_trend(st)

  both_set <- !is.na(as.numeric(out[, "up"])) &
              !is.na(as.numeric(out[, "down"]))
  expect_true(!any(both_set))
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `R -e "devtools::test(filter = 'split-by-trend')"`
Expected: FAIL with "could not find function 'split_by_trend'" (or similar — function not yet defined in package namespace).

- [ ] **Step 3: Implement `split_by_trend()`**

Add to `R/addSuperTrend.R` ABOVE the existing `addSuperTrend` definition (after the file's leading comments / before the roxygen block of `addSuperTrend`). Insert:

```r
# Split a SuperTrend output into two trend-masked columns for bicolor
# rendering. `up` carries the supertrend value where trend == +1 (NA
# elsewhere); `down` carries it where trend == -1. Warm-up rows (trend
# is NA) are NA in both columns. By construction the two columns never
# have a non-NA value in the same row.
split_by_trend <- function(st) {
  trend <- as.numeric(st[, "trend"])
  vals  <- as.numeric(st[, "supertrend"])

  up   <- ifelse(!is.na(trend) & trend ==  1L, vals, NA_real_)
  down <- ifelse(!is.na(trend) & trend == -1L, vals, NA_real_)

  xts::xts(cbind(up = up, down = down), order.by = zoo::index(st))
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `R -e "devtools::test(filter = 'split-by-trend')"`
Expected: all 5 tests in `test-split-by-trend.R` pass.

- [ ] **Step 5: Commit**

```bash
git add R/addSuperTrend.R tests/testthat/test-split-by-trend.R
git commit -m "$(cat <<'EOF'
Add split_by_trend() internal helper with tests

Pure xts transform: takes a SuperTrend() output and returns a 2-column
xts (up/down) where each column has the supertrend value only on bars
matching that trend direction (NA elsewhere). This is the data shape
addSuperTrend will pass to a single quantmod::addTA call for bicolor
rendering.
EOF
)"
```

---

### Task 2: Update `addSuperTrend()` for bicolor rendering

Replace the v0.1.0 single-color line with a single multi-column `addTA` call. Update the `col` validation to require length-2 character. Drop the explicit `flips → NA` masking (trend masking already produces a 1-bar gap at flips).

**Files:**
- Modify: `R/addSuperTrend.R` (the `addSuperTrend()` function body)

- [ ] **Step 1: Update the `addSuperTrend()` function**

Replace the existing `addSuperTrend()` function in `R/addSuperTrend.R` (currently lines 29–84 of v0.1.0) with the bicolor version below. Keep the `split_by_trend()` helper added in Task 1 untouched. Replace the entire function (roxygen block + body):

```r
#' Add SuperTrend Overlay to an Active 'quantmod' Chart
#'
#' Adds a bicolor SuperTrend line to the price panel of the currently
#' active \code{\link[quantmod]{chartSeries}} chart. Behaves like
#' \code{\link[quantmod]{addBBands}}: must be called after the chart
#' has been drawn, draws on the price panel by default.
#'
#' The line is drawn in two colors: \code{col[1]} on bars where
#' \code{trend == +1} (uptrend) and \code{col[2]} on bars where
#' \code{trend == -1} (downtrend). The colors do not connect across
#' trend-flip bars: at each flip the up-segment ends and the
#' down-segment begins (or vice versa) on different bands, producing
#' the canonical SuperTrend visual break.
#'
#' @param n,multiplier,atr_method Passed through to
#'   \code{\link{SuperTrend}}.
#' @param col Length-2 character vector of colors. \code{col[1]} is
#'   used for uptrend bars (\code{trend == +1}); \code{col[2]} for
#'   downtrend bars (\code{trend == -1}). Defaults to TradingView's
#'   green / red.
#' @param lwd Line width.
#' @param on Chart panel to draw on. \code{1} = price panel (the
#'   default and the only sensible choice for SuperTrend).
#'
#' @return Invisibly, the result of the underlying
#'   \code{\link[quantmod]{addTA}} call.
#'
#' @examples
#' \dontrun{
#'   data(spy_sample)
#'   quantmod::chartSeries(spy_sample, theme = "white")
#'   addSuperTrend()
#' }
#'
#' @export
addSuperTrend <- function(n = 10, multiplier = 3,
                          atr_method = c("wilder", "sma", "ema"),
                          col = c("#26a69a", "#ef5350"),
                          lwd = 2, on = 1) {
  atr_method <- match.arg(atr_method)
  if (!is.character(col) || length(col) != 2L) {
    stop("col must be a length-2 character vector: c(uptrend, downtrend)")
  }
  if (!is.numeric(lwd) || length(lwd) != 1L || !is.finite(lwd) || lwd <= 0) {
    stop("lwd must be a positive number")
  }
  if (!is.numeric(on) || length(on) != 1L || !is.finite(on) ||
      on != as.integer(on) || on < 1) {
    stop("on must be a positive integer panel index")
  }

  get_chob <- utils::getFromNamespace("get.current.chob", "quantmod")
  lchob <- get_chob()
  if (is.null(lchob)) {
    stop("addSuperTrend() must be called after an active chartSeries() chart")
  }
  x <- lchob@xdata

  st <- SuperTrend(x, n = n, multiplier = multiplier,
                   atr_method = atr_method)
  stx <- split_by_trend(st)

  # quantmod::addTA uses NSE: it captures the call expression and
  # re-evaluates the data symbol at draw time. From a package namespace
  # the local variable isn't found, so the line silently fails to
  # render. Workaround: bind the xts to the name "SuperTrend" in a
  # fresh environment whose parent is .GlobalEnv, then evaluate the
  # addTA call there. addTA's NSE finds the symbol; the user's
  # workspace stays clean.
  ta_env <- new.env(parent = .GlobalEnv)
  assign("SuperTrend", stx, envir = ta_env)

  ta <- eval(
    bquote(quantmod::addTA(SuperTrend, on = .(on), type = "l",
                           col = .(col), lwd = .(lwd))),
    envir = ta_env
  )
  plot(ta)
  invisible(ta)
}
```

The eval-in-env block in the function body bypasses `addTA`'s non-standard evaluation when called from a package namespace. It has two meaningful differences from v0.1.0: (1) the variable bound into the environment is `stx` (the 2-column xts) instead of `st_line`, (2) the `colnames(...) <- "SuperTrend"` line is removed because `split_by_trend()` already names its columns. Everything else — the comment, the `new.env(parent = .GlobalEnv)` line, the `bquote` / evaluation shape — is identical to v0.1.0.

Notes for the implementer:
- The v0.1.0 `flips`/`st_line` block (lines 55–59 of v0.1.0) and the deferred-bicolor comment block (lines 62–65) are both gone.
- `col` default and validation message both change. The new validation message is the one the updated tests in Task 4 will assert on.

- [ ] **Step 2: Regenerate man pages**

Run: `R -e "devtools::document()"`
Expected: `man/addSuperTrend.Rd` updated to reflect the new `@param col` description and default.

- [ ] **Step 3: Smoke-test interactively**

Run:
```
R -e 'devtools::load_all(); pdf("/tmp/bicolor-smoke.pdf"); data(spy_sample); quantmod::chartSeries(spy_sample, theme = "white"); addSuperTrend(); dev.off()'
```
Expected: no errors. Open `/tmp/bicolor-smoke.pdf` and confirm the SuperTrend line is two colors (green during uptrends, red during downtrends), with visible breaks at flips.

- [ ] **Step 4: Commit**

```bash
git add R/addSuperTrend.R man/addSuperTrend.Rd
git commit -m "$(cat <<'EOF'
Render addSuperTrend overlay in bicolor by trend direction

Single quantmod::addTA call with a 2-column xts (up/down trend masks)
and col=c(green, red). quantmod recycles col across columns, so one
TA registration draws both. Sidesteps the chob-accumulation problem
that defeated the two-call bicolor approach deferred from v0.1.0.

Breaking change: col is now a length-2 character vector (was scalar).
EOF
)"
```

---

### Task 3: Update `chartSuperTrend()` to mirror the new `col` contract

Wrapper just needs its default and pass-through updated.

**Files:**
- Modify: `R/chartSuperTrend.R`

- [ ] **Step 1: Update the function signature and roxygen**

Replace the entire contents of `R/chartSuperTrend.R` with:

```r
#' Chart a Series with SuperTrend Overlay
#'
#' Convenience wrapper that draws a \code{\link[quantmod]{chartSeries}}
#' price chart and overlays the bicolor SuperTrend line in one call.
#'
#' @param x An \code{xts} OHLC series.
#' @param ... Additional arguments passed to
#'   \code{\link[quantmod]{chartSeries}} (e.g., \code{theme}, \code{type},
#'   \code{subset}, \code{TA}).
#' @param name Chart title. Defaults to the deparsed input expression.
#' @param n,multiplier,atr_method,col Passed through to
#'   \code{\link{addSuperTrend}}. \code{col} is a length-2 character
#'   vector: uptrend color, downtrend color.
#'
#' @return Invisibly \code{NULL}; called for the side effect of drawing.
#'
#' @examples
#' \dontrun{
#'   data(spy_sample)
#'   chartSuperTrend(spy_sample, theme = "white")
#' }
#'
#' @export
chartSuperTrend <- function(x, ..., name = deparse(substitute(x)),
                            n = 10, multiplier = 3,
                            atr_method = c("wilder", "sma", "ema"),
                            col = c("#26a69a", "#ef5350")) {
  atr_method <- match.arg(atr_method)
  quantmod::chartSeries(x, name = name, ...)
  addSuperTrend(n = n, multiplier = multiplier,
                atr_method = atr_method, col = col)
  invisible(NULL)
}
```

- [ ] **Step 2: Regenerate man pages**

Run: `R -e "devtools::document()"`
Expected: `man/chartSuperTrend.Rd` updated.

- [ ] **Step 3: Commit**

```bash
git add R/chartSuperTrend.R man/chartSuperTrend.Rd
git commit -m "$(cat <<'EOF'
Update chartSuperTrend default col to bicolor green/red

Mirrors the addSuperTrend signature change. col is now a length-2
character vector (uptrend, downtrend).
EOF
)"
```

---

### Task 4: Update existing `test-addSuperTrend.R` for the new `col` contract

The v0.1.0 tests check that a length-2 `col` is rejected and that a length-1 `col` is accepted. Both expectations are now inverted. Add new tests for the bicolor contract.

**Files:**
- Modify: `tests/testthat/test-addSuperTrend.R`

- [ ] **Step 1: Replace the file with the updated test suite**

Replace the entire contents of `tests/testthat/test-addSuperTrend.R` with:

```r
test_that("chartSuperTrend runs without error on the sample dataset", {
  skip_on_cran()  # rendering is fragile across CRAN's headless devices

  pdf(file = NULL)
  on.exit(dev.off(), add = TRUE)

  data(spy_sample, package = "supertrend")
  expect_no_error(chartSuperTrend(spy_sample, n = 10, multiplier = 3))
})

test_that("addSuperTrend errors when no chart is active", {
  # No active chart -> quantmod's addTA errors; we want some error.
  if (!is.null(dev.list())) {
    for (d in dev.list()) dev.off()
  }
  expect_error(addSuperTrend())
})

test_that("addSuperTrend accepts a custom length-2 col vector", {
  skip_on_cran()

  pdf(file = NULL)
  on.exit(dev.off(), add = TRUE)

  data(spy_sample, package = "supertrend")
  expect_no_error(
    chartSuperTrend(spy_sample, col = c("forestgreen", "firebrick"))
  )
})

test_that("addSuperTrend rejects a length-1 col (scalar no longer allowed)", {
  skip_on_cran()

  pdf(file = NULL)
  on.exit(dev.off(), add = TRUE)

  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample, theme = "white")
  expect_error(addSuperTrend(col = "blue"),
               "col must be a length-2 character vector")
})

test_that("addSuperTrend rejects a length-3 col", {
  skip_on_cran()

  pdf(file = NULL)
  on.exit(dev.off(), add = TRUE)

  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample, theme = "white")
  expect_error(addSuperTrend(col = c("a", "b", "c")),
               "col must be a length-2 character vector")
})

test_that("addSuperTrend rejects non-character col", {
  skip_on_cran()

  pdf(file = NULL)
  on.exit(dev.off(), add = TRUE)

  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample, theme = "white")
  expect_error(addSuperTrend(col = c(1, 2)),
               "col must be a length-2 character vector")
})

test_that("addSuperTrend rejects invalid lwd", {
  skip_on_cran()
  pdf(file = NULL)
  on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample, theme = "white")
  expect_error(addSuperTrend(lwd = "two"),  "lwd must be a positive number")
  expect_error(addSuperTrend(lwd = 0),      "lwd must be a positive number")
  expect_error(addSuperTrend(lwd = -1),     "lwd must be a positive number")
})

test_that("addSuperTrend rejects invalid on", {
  skip_on_cran()
  pdf(file = NULL)
  on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample, theme = "white")
  expect_error(addSuperTrend(on = 0),    "on must be a positive integer panel index")
  expect_error(addSuperTrend(on = -1),   "on must be a positive integer panel index")
  expect_error(addSuperTrend(on = 1.5),  "on must be a positive integer panel index")
  expect_error(addSuperTrend(on = "1"),  "on must be a positive integer panel index")
})
```

Changes versus v0.1.0:
- "accepts a custom color and lwd" → "accepts a custom length-2 col vector" (passes a length-2 vector now).
- "rejects multi-element col vector" (which expected length-2 to error) is REMOVED and replaced by three new tests asserting length-1, length-3, and non-character all error with the new message `"col must be a length-2 character vector"`.

- [ ] **Step 2: Run the full test suite**

Run: `R -e "devtools::test()"`
Expected: all tests pass, including the new ones.

- [ ] **Step 3: Commit**

```bash
git add tests/testthat/test-addSuperTrend.R
git commit -m "$(cat <<'EOF'
Update addSuperTrend tests for the bicolor col contract

col is now required to be length-2 character. Replace the v0.1.0
"length-2 errors / length-1 accepted" tests with the inverse, and add
length-3 + non-character rejection tests.
EOF
)"
```

---

### Task 5: Update vignette and README

The vignette describes the line as "single color (default blue) ... bicolor by trend direction is a planned v0.2.0 enhancement." That sentence is now wrong. The README roadmap also lists v0.2.0 bicolor as planned.

**Files:**
- Modify: `vignettes/supertrend.Rmd:49-51`
- Modify: `README.md:50-53`

- [ ] **Step 1: Update the vignette text**

In `vignettes/supertrend.Rmd`, replace lines 49–51 (the paragraph beginning "The SuperTrend line is drawn in a single color (default blue)..."). Find the existing block:

```
The SuperTrend line is drawn in a single color (default blue) with
breaks at trend-flip bars; bicolor by trend direction is a planned
v0.2.0 enhancement. To layer it onto an existing chart instead, use
```

Replace with:

```
The SuperTrend line is drawn in two colors — green during uptrends
(`trend == +1`) and red during downtrends (`trend == -1`) — with a
visible break at each trend flip. To layer it onto an existing chart
instead, use
```

- [ ] **Step 2: Update README roadmap**

In `README.md`, find:

```
## Roadmap

- v0.2.0: bicolor SuperTrend overlay (green during uptrends, red during downtrends).
- v0.2.0: ggplot2-based visualization function for non-quantmod workflows.
```

Replace with:

```
## Roadmap

- v0.3.0: ggplot2-based visualization function for non-quantmod workflows.
```

(The bicolor item is now shipped; the ggplot2 item bumps to the next version since v0.2.0's scope is the bicolor change alone.)

- [ ] **Step 3: Commit**

```bash
git add vignettes/supertrend.Rmd README.md
git commit -m "$(cat <<'EOF'
Update vignette and README for bicolor overlay

Vignette text now describes the green/red rendering instead of
flagging it as a planned v0.2.0 enhancement. README roadmap drops the
shipped bicolor item and bumps the ggplot2 item to v0.3.0.
EOF
)"
```

---

### Task 6: Add `NEWS.md`

No `NEWS.md` exists yet. Create one with a v0.2.0 entry calling out the breaking API change, and a back-dated v0.1.0 entry so the file reads as a complete changelog.

**Files:**
- Create: `NEWS.md`

- [ ] **Step 1: Create the file**

Create `NEWS.md`:

```markdown
# supertrend 0.2.0

## Breaking changes

* `addSuperTrend()` and `chartSuperTrend()` now render the SuperTrend
  line in two colors: `col[1]` (default `"#26a69a"`, green) on uptrend
  bars and `col[2]` (default `"#ef5350"`, red) on downtrend bars.
  `col` must now be a length-2 character vector. Code that passed a
  scalar color in v0.1.0 will need to pass a length-2 vector.

# supertrend 0.1.0

* Initial release.
* `SuperTrend()`: ATR-based trailing-stop trend indicator with
  `wilder` (default), `sma`, and `ema` ATR smoothing methods.
* `supertrend_signals()`: long/short entry and exit flags on
  trend flips.
* `addSuperTrend()` and `chartSuperTrend()`: quantmod-idiomatic
  chart overlays.
* Built-in `spy_sample` synthetic OHLC dataset.
```

- [ ] **Step 2: Confirm `NEWS.md` is not in `.Rbuildignore`**

Run: `cat .Rbuildignore`

`NEWS.md` should NOT be in `.Rbuildignore` — CRAN expects it to ship with the package. If it is listed there, remove the line. If not, no action.

- [ ] **Step 3: Commit**

```bash
git add NEWS.md
git commit -m "$(cat <<'EOF'
Add NEWS.md with v0.2.0 breaking-change entry

v0.2.0: addSuperTrend / chartSuperTrend col is now length-2 (bicolor
by trend direction). Includes a back-dated v0.1.0 entry so the
changelog is complete.
EOF
)"
```

---

### Task 7: Bump `DESCRIPTION` to 0.2.0

**Files:**
- Modify: `DESCRIPTION:4`

- [ ] **Step 1: Bump the version**

In `DESCRIPTION`, change:

```
Version: 0.1.0
```

to:

```
Version: 0.2.0
```

- [ ] **Step 2: Commit**

```bash
git add DESCRIPTION
git commit -m "Bump version to 0.2.0"
```

---

### Task 8: Run `R CMD check --as-cran` and confirm clean

Final gate. The package shipped clean at v0.1.0 and the changes here are minor; expect 0 errors / 0 warnings / 0 notes (except the unavoidable "new submission" note that we ignore for non-CRAN runs).

**Files:** none modified in this task.

- [ ] **Step 1: Build the package tarball**

Run from the repo root: `R CMD build .`
Expected: produces `supertrend_0.2.0.tar.gz` in the working directory.

- [ ] **Step 2: Run the check**

Run: `R CMD check --as-cran supertrend_0.2.0.tar.gz`
Expected: `Status: OK` at the end. If there are NOTEs / WARNINGs / ERRORs, fix them before proceeding (do not commit broken state).

- [ ] **Step 3: Clean up the tarball**

Run: `rm supertrend_0.2.0.tar.gz`
(Tarball is a build artifact, not committed.)

- [ ] **Step 4: No commit (verification only)**

This task produces no code changes. If everything passes, the v0.2.0 implementation is done.

---

## Self-review checklist (already run)

- **Spec coverage:** Approach (Task 0–2), API (Task 2–3), validation (Task 4), edge cases (Task 1), testing (Task 1, 4), docs (Task 5–6), version bump (Task 7), CRAN clean (Task 8). All sections covered.
- **No placeholders:** No "TBD" / "TODO" / "implement later". Every step has the actual code or command.
- **Type/name consistency:** `split_by_trend` (Task 1) is referenced in Task 2 with the same name. `col` validation message `"col must be a length-2 character vector"` is identical in Task 2 (impl) and Task 4 (tests). `up`/`down` column names are used consistently.
- **Bite-sized:** Each step is one mechanical action. Largest is Task 4's full file replacement, which is one paste.
