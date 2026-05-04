# supertrend v0.3.0 — Signal Triangles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add TradingView-style buy/sell signal triangles to the SuperTrend chart overlay. Green up-triangles below the Low on flip-up bars, red down-triangles above the High on flip-down bars. Exposed via a new `addSuperTrendSignals()` and a default-on `signals = TRUE` flag on `addSuperTrend()` / `chartSuperTrend()`.

**Architecture:** New internal helper `signal_markers(st, hi, lo, offset)` produces two single-column xts (`buy`, `sell`) of marker y-coordinates aligned to the input index. New exported `addSuperTrendSignals()` consumes the helper and draws via two `quantmod::addTA(..., type = "p")` calls — same NSE-bypass wrapper already used in `addSuperTrend()` (`R/addSuperTrend.R:98-113`), just with point-style overlays instead of lines. `addSuperTrend()` and `chartSuperTrend()` gain a default-on `signals` flag that calls the new function after the bicolor line is drawn.

**Tech Stack:** R, xts, zoo, quantmod, TTR, testthat (edition 3), roxygen2.

**Spec:** `docs/superpowers/specs/2026-05-03-supertrend-signal-triangles-design.md`

> **Note on rendering code blocks:** Several R code samples below use the same NSE-bypass pattern that `R/addSuperTrend.R` already uses. Where you see `base::eval (bquote(...), envir = ta_env)` (with a space before the open paren), the space is cosmetic — R parses it identically to the no-space form. Existing code in the repo uses the no-space form; **when typing the actual implementation into source files, remove the cosmetic space** so the output matches the existing convention.

---

### Task 0: De-risk filled-triangle rendering

**Why:** `pch = 24` and `pch = 25` are open triangles that need `bg` set to render as filled. quantmod's `addTA(type = "p")` *should* forward `bg` through to the underlying plot, but historically some quantmod versions strip it. Confirm filled rendering before writing the implementation, so Task 2 can pick the right `pch` defaults.

**Files:**
- Create: `/tmp/verify-triangles.R` (throwaway verification script)
- Create: `/tmp/verify-triangles.pdf` (artifact for visual inspection)

- [ ] **Step 1: Write the verification script**

Create `/tmp/verify-triangles.R`:

```r
# Verification: do filled triangles render through quantmod::addTA?
# Draws two attempts to a PDF: pch=24/25 with bg, and pch=17/25 with col only.
# Open the PDF and confirm both attempts show *filled* triangles.

library(supertrend)
library(quantmod)
data(spy_sample, package = "supertrend")

idx <- zoo::index(spy_sample)
hi  <- as.numeric(quantmod::Hi(spy_sample))
lo  <- as.numeric(quantmod::Lo(spy_sample))

n <- length(idx)
buy_y  <- rep(NA_real_, n); buy_y[c(20, 60, 100)]  <- lo[c(20, 60, 100)]  - 1
sell_y <- rep(NA_real_, n); sell_y[c(40, 80, 120)] <- hi[c(40, 80, 120)] + 1

buy_xts  <- xts::xts(matrix(buy_y,  ncol = 1, dimnames = list(NULL, "buy")),
                     order.by = idx)
sell_xts <- xts::xts(matrix(sell_y, ncol = 1, dimnames = list(NULL, "sell")),
                     order.by = idx)

pdf("/tmp/verify-triangles.pdf", width = 10, height = 6)

# Attempt A: pch=24/25 with bg.
chartSeries(spy_sample, name = "Attempt A: pch=24/25 + bg")
ta_env <- new.env(parent = .GlobalEnv)
assign("buy_xts",  buy_xts,  envir = ta_env)
assign("sell_xts", sell_xts, envir = ta_env)

ta_b <- base::eval (bquote(quantmod::addTA(buy_xts,  on = 1, type = "p",
                                           pch = 24, col = "#26a69a",
                                           bg = "#26a69a", cex = 1.6)),
                    envir = ta_env)
ta_s <- base::eval (bquote(quantmod::addTA(sell_xts, on = 1, type = "p",
                                           pch = 25, col = "#ef5350",
                                           bg = "#ef5350", cex = 1.6)),
                    envir = ta_env)
plot(ta_b); plot(ta_s)

# Attempt B: pch=17 (already-filled up) and pch=25 with col only.
chartSeries(spy_sample, name = "Attempt B: pch=17/25 + col only")
ta_b2 <- base::eval (bquote(quantmod::addTA(buy_xts,  on = 1, type = "p",
                                            pch = 17, col = "#26a69a",
                                            cex = 1.6)),
                     envir = ta_env)
ta_s2 <- base::eval (bquote(quantmod::addTA(sell_xts, on = 1, type = "p",
                                            pch = 25, col = "#ef5350",
                                            cex = 1.6)),
                     envir = ta_env)
plot(ta_b2); plot(ta_s2)

dev.off()
cat("Wrote /tmp/verify-triangles.pdf — open and inspect.\n")
```

(Remove the cosmetic spaces before `(` on each `base::eval` line when actually running the script — the file as typed above will work either way, the space is harmless.)

- [ ] **Step 2: Run the verification script**

Run: `Rscript /tmp/verify-triangles.R`
Expected: prints "Wrote /tmp/verify-triangles.pdf — open and inspect.", no errors.

- [ ] **Step 3: Inspect the PDF and pick the working `pch` pair**

Open `/tmp/verify-triangles.pdf`. Look at both pages.

- If page 1 (Attempt A) shows **filled** green up-triangles and **filled** red down-triangles, use `pch = c(24, 25)` with `bg = col` in the implementation. This is the preferred path.
- If page 1 shows **outlined** (open) triangles or no fill, fall back to page 2 (Attempt B) — use `pch = c(17, 25)` with `col` only and **no `bg`**. Document the choice in `NEWS.md` (Task 7) so future readers know why the asymmetry.

Record the choice in a one-line note: which `pch` pair, with or without `bg`. This decision drives the `pch` defaults and the rendering body in Task 2.

- [ ] **Step 4: Clean up**

Run: `rm /tmp/verify-triangles.R /tmp/verify-triangles.pdf`

No commit — this task produces no source changes, only a one-time verification decision.

---

### Task 1: Add `signal_markers()` internal helper (TDD)

Pure data-transform function. Takes the xts that `SuperTrend()` returns plus High/Low vectors, produces a list with two single-column xts (`buy`, `sell`) of marker y-coordinates. Internal (not exported), unit-testable without rendering.

**Files:**
- Create: `R/signal_markers.R`
- Create: `tests/testthat/test-signal-markers.R`

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-signal-markers.R`:

```r
test_that("signal_markers returns a list of two single-column xts named buy/sell", {
  hlc <- make_mixed_hlc()
  st  <- SuperTrend(hlc, n = 10, multiplier = 3)
  hi  <- as.numeric(quantmod::Hi(hlc))
  lo  <- as.numeric(quantmod::Lo(hlc))

  out <- supertrend:::signal_markers(st, hi, lo, offset = 0.015)

  expect_type(out, "list")
  expect_named(out, c("buy", "sell"))
  expect_true(xts::is.xts(out$buy))
  expect_true(xts::is.xts(out$sell))
  expect_equal(ncol(out$buy),  1L)
  expect_equal(ncol(out$sell), 1L)
  expect_equal(zoo::index(out$buy),  zoo::index(st))
  expect_equal(zoo::index(out$sell), zoo::index(st))
})

test_that("signal_markers buy/sell counts match supertrend_signals flip counts", {
  hlc <- make_mixed_hlc()
  st  <- SuperTrend(hlc, n = 10, multiplier = 3)
  hi  <- as.numeric(quantmod::Hi(hlc))
  lo  <- as.numeric(quantmod::Lo(hlc))
  sig <- supertrend_signals(st)

  out <- supertrend:::signal_markers(st, hi, lo, offset = 0.015)

  expect_equal(sum(!is.na(as.numeric(out$buy))),
               sum(as.integer(sig[, "long_entry"])))
  expect_equal(sum(!is.na(as.numeric(out$sell))),
               sum(as.integer(sig[, "short_entry"])))
})

test_that("signal_markers buy y-values equal Lo - pad on flip-up bars", {
  hlc <- make_mixed_hlc()
  st  <- SuperTrend(hlc, n = 10, multiplier = 3)
  hi  <- as.numeric(quantmod::Hi(hlc))
  lo  <- as.numeric(quantmod::Lo(hlc))
  offset <- 0.015
  pad <- offset * (max(hi) - min(lo))

  out <- supertrend:::signal_markers(st, hi, lo, offset = offset)

  trend <- as.numeric(st[, "trend"])
  prev  <- c(NA, head(trend, -1))
  flip_up <- which(!is.na(prev) & !is.na(trend) & prev == -1 & trend == 1)

  expect_true(length(flip_up) > 0L)
  expect_equal(as.numeric(out$buy)[flip_up], lo[flip_up] - pad)
})

test_that("signal_markers sell y-values equal Hi + pad on flip-down bars", {
  hlc <- make_mixed_hlc()
  st  <- SuperTrend(hlc, n = 10, multiplier = 3)
  hi  <- as.numeric(quantmod::Hi(hlc))
  lo  <- as.numeric(quantmod::Lo(hlc))
  offset <- 0.015
  pad <- offset * (max(hi) - min(lo))

  out <- supertrend:::signal_markers(st, hi, lo, offset = offset)

  trend <- as.numeric(st[, "trend"])
  prev  <- c(NA, head(trend, -1))
  flip_down <- which(!is.na(prev) & !is.na(trend) & prev == 1 & trend == -1)

  expect_true(length(flip_down) > 0L)
  expect_equal(as.numeric(out$sell)[flip_down], hi[flip_down] + pad)
})

test_that("signal_markers leaves warm-up rows NA in both buy and sell", {
  hlc <- make_mixed_hlc()
  st  <- SuperTrend(hlc, n = 10, multiplier = 3)
  hi  <- as.numeric(quantmod::Hi(hlc))
  lo  <- as.numeric(quantmod::Lo(hlc))

  out <- supertrend:::signal_markers(st, hi, lo, offset = 0.015)

  trend <- as.numeric(st[, "trend"])
  warmup <- which(is.na(trend))
  expect_true(length(warmup) > 0L)
  expect_true(all(is.na(as.numeric(out$buy)[warmup])))
  expect_true(all(is.na(as.numeric(out$sell)[warmup])))
})

test_that("signal_markers never has both buy and sell non-NA in the same row", {
  hlc <- make_mixed_hlc()
  st  <- SuperTrend(hlc, n = 10, multiplier = 3)
  hi  <- as.numeric(quantmod::Hi(hlc))
  lo  <- as.numeric(quantmod::Lo(hlc))

  out <- supertrend:::signal_markers(st, hi, lo, offset = 0.015)

  both_set <- !is.na(as.numeric(out$buy)) & !is.na(as.numeric(out$sell))
  expect_true(!any(both_set))
})

test_that("signal_markers handles all-uptrend series (no flips after seed)", {
  hlc <- make_monotonic_up_hlc(n = 40)
  st  <- SuperTrend(hlc, n = 10, multiplier = 3)
  hi  <- as.numeric(quantmod::Hi(hlc))
  lo  <- as.numeric(quantmod::Lo(hlc))

  out <- supertrend:::signal_markers(st, hi, lo, offset = 0.015)

  # After warm-up, trend stays at +1 throughout — no -1 -> +1 flip and
  # no +1 -> -1 flip occur, so both layers are entirely NA.
  expect_true(all(is.na(as.numeric(out$buy))))
  expect_true(all(is.na(as.numeric(out$sell))))
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `R -q -e "devtools::test(filter = 'signal-markers')"`
Expected: all 7 tests fail with "could not find function \"signal_markers\"".

- [ ] **Step 3: Implement `signal_markers()`**

Create `R/signal_markers.R`:

```r
# Build buy/sell marker layers from a SuperTrend result. Returns a list
# of two single-column xts:
#   buy[i]  = lo[i] - pad  on bars where trend flips -1 -> +1, NA elsewhere
#   sell[i] = hi[i] + pad  on bars where trend flips +1 -> -1, NA elsewhere
# pad = offset * (max(hi) - min(lo)) — a fraction of the visible panel
# range so markers sit just outside the candle. By construction, buy
# and sell never share a non-NA row (a flip is up XOR down).
#
# st: xts returned by SuperTrend() (must contain a `trend` column).
# hi, lo: numeric vectors of High and Low aligned to st (same length).
# offset: positive numeric — fraction of panel range used as padding.
signal_markers <- function(st, hi, lo, offset) {
  trend <- as.numeric(st[, "trend"])
  prev  <- c(NA_real_, utils::head(trend, -1))

  flip_up   <- !is.na(prev) & !is.na(trend) & prev == -1 & trend == 1
  flip_down <- !is.na(prev) & !is.na(trend) & prev == 1  & trend == -1

  panel_range <- max(hi, na.rm = TRUE) - min(lo, na.rm = TRUE)
  pad <- offset * panel_range

  buy_y  <- ifelse(flip_up,   lo - pad, NA_real_)
  sell_y <- ifelse(flip_down, hi + pad, NA_real_)

  idx <- zoo::index(st)
  list(
    buy  = xts::xts(matrix(buy_y,  ncol = 1L,
                           dimnames = list(NULL, "buy")),
                    order.by = idx),
    sell = xts::xts(matrix(sell_y, ncol = 1L,
                           dimnames = list(NULL, "sell")),
                    order.by = idx)
  )
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `R -q -e "devtools::test(filter = 'signal-markers')"`
Expected: all 7 tests pass.

- [ ] **Step 5: Run the full test suite to confirm no regressions**

Run: `R -q -e "devtools::test()"`
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add R/signal_markers.R tests/testthat/test-signal-markers.R
git commit -m "Add signal_markers() helper for trend-flip overlay markers"
```

---

### Task 2: Add `addSuperTrendSignals()` exported function (TDD)

The new exported overlay function. Validates arguments, computes markers via `signal_markers()`, draws two `addTA` point layers using the same NSE-bypass wrapper as `addSuperTrend()`.

**Files:**
- Create: `R/addSuperTrendSignals.R`
- Create: `tests/testthat/test-addSuperTrendSignals.R`

- [ ] **Step 1: Write the failing tests**

Create `tests/testthat/test-addSuperTrendSignals.R`:

```r
test_that("addSuperTrendSignals runs without error on the sample dataset", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample)
  expect_no_error(addSuperTrendSignals())
})

test_that("addSuperTrendSignals errors when no chart is active", {
  if (!is.null(dev.list())) {
    for (d in dev.list()) dev.off()
  }
  expect_error(addSuperTrendSignals())
})

test_that("addSuperTrendSignals rejects bad col vectors", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample)

  expect_error(addSuperTrendSignals(col = "blue"),
               "col must be a length-2 character vector")
  expect_error(addSuperTrendSignals(col = c("a", "b", "c")),
               "col must be a length-2 character vector")
  expect_error(addSuperTrendSignals(col = c(1, 2)),
               "col must be a length-2 character vector")
  expect_error(addSuperTrendSignals(col = c("blue", NA)),
               "col must be a length-2 character vector")
  expect_error(addSuperTrendSignals(col = c("", "red")),
               "col must be a length-2 character vector")
})

test_that("addSuperTrendSignals rejects bad pch vectors", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample)

  expect_error(addSuperTrendSignals(pch = 24),
               "pch must be a length-2 numeric vector")
  expect_error(addSuperTrendSignals(pch = c(24, 25, 17)),
               "pch must be a length-2 numeric vector")
  expect_error(addSuperTrendSignals(pch = c(24, NA)),
               "pch must be a length-2 numeric vector")
  expect_error(addSuperTrendSignals(pch = c("a", "b")),
               "pch must be a length-2 numeric vector")
})

test_that("addSuperTrendSignals rejects invalid cex", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample)

  expect_error(addSuperTrendSignals(cex = "two"),  "cex must be a positive number")
  expect_error(addSuperTrendSignals(cex = 0),      "cex must be a positive number")
  expect_error(addSuperTrendSignals(cex = -1),     "cex must be a positive number")
  expect_error(addSuperTrendSignals(cex = c(1, 2)),"cex must be a positive number")
})

test_that("addSuperTrendSignals rejects invalid offset", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample)

  expect_error(addSuperTrendSignals(offset = "x"),  "offset must be a positive number")
  expect_error(addSuperTrendSignals(offset = 0),    "offset must be a positive number")
  expect_error(addSuperTrendSignals(offset = -1),   "offset must be a positive number")
})

test_that("addSuperTrendSignals rejects invalid on", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample)

  expect_error(addSuperTrendSignals(on = 0),    "on must be a positive integer panel index")
  expect_error(addSuperTrendSignals(on = -1),   "on must be a positive integer panel index")
  expect_error(addSuperTrendSignals(on = 1.5),  "on must be a positive integer panel index")
  expect_error(addSuperTrendSignals(on = "1"),  "on must be a positive integer panel index")
})
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `R -q -e "devtools::test(filter = 'addSuperTrendSignals')"`
Expected: all tests fail with "could not find function \"addSuperTrendSignals\"".

- [ ] **Step 3: Implement `addSuperTrendSignals()`**

Create `R/addSuperTrendSignals.R`. **Defaults below assume Task 0 verified `pch = c(24, 25)` + `bg` works.** If Task 0 selected the fallback, change `pch = c(24, 25)` to `pch = c(17, 25)` and remove the two `bg = .(col[N])` arguments.

```r
#' Add Buy/Sell Signal Triangles to an Active 'quantmod' Chart
#'
#' Adds TradingView-style trend-flip markers to the price panel of the
#' currently active \code{\link[quantmod]{chartSeries}} chart. A green
#' up-triangle is drawn just below the Low of every bar where the
#' SuperTrend flips to uptrend; a red down-triangle is drawn just
#' above the High of every bar where it flips to downtrend.
#'
#' @param n,multiplier,atr_method Passed through to
#'   \code{\link{SuperTrend}}.
#' @param col Length-2 character vector of colors. \code{col[1]} is
#'   used for buy markers (flip-up); \code{col[2]} for sell markers
#'   (flip-down). Defaults to TradingView's green / red.
#' @param pch Length-2 numeric vector of plot characters.
#'   \code{pch[1]} for buy markers, \code{pch[2]} for sell markers.
#'   Defaults to \code{c(24, 25)} (filled up-triangle, filled
#'   down-triangle).
#' @param cex Positive numeric. Marker size multiplier. Defaults to 1.2.
#' @param offset Positive numeric. Fraction of the visible panel price
#'   range used to pad markers off the candle so the triangle never
#'   overlaps the wick. Defaults to 0.015 (1.5\%).
#' @param on Chart panel to draw on. \code{1} = price panel (the only
#'   sensible choice for SuperTrend signals).
#'
#' @return Invisibly \code{NULL}; called for the side effect of drawing
#'   two overlay layers on the active chart.
#'
#' @examples
#' if (interactive()) {
#'   data(spy_sample)
#'   quantmod::chartSeries(spy_sample)
#'   addSuperTrend(signals = FALSE)
#'   addSuperTrendSignals()
#' }
#'
#' @export
addSuperTrendSignals <- function(n = 10, multiplier = 3,
                                 atr_method = c("wilder", "sma", "ema"),
                                 col = c("#26a69a", "#ef5350"),
                                 pch = c(24, 25),
                                 cex = 1.2,
                                 offset = 0.015,
                                 on = 1) {
  atr_method <- match.arg(atr_method)
  if (!is.character(col) || length(col) != 2L ||
      anyNA(col) || any(!nzchar(col))) {
    stop("col must be a length-2 character vector: c(buy, sell)")
  }
  if (!is.numeric(pch) || length(pch) != 2L || anyNA(pch)) {
    stop("pch must be a length-2 numeric vector: c(buy, sell)")
  }
  if (!is.numeric(cex) || length(cex) != 1L || !is.finite(cex) || cex <= 0) {
    stop("cex must be a positive number")
  }
  if (!is.numeric(offset) || length(offset) != 1L ||
      !is.finite(offset) || offset <= 0) {
    stop("offset must be a positive number")
  }
  if (!is.numeric(on) || length(on) != 1L || !is.finite(on) ||
      on != as.integer(on) || on < 1) {
    stop("on must be a positive integer panel index")
  }

  get_chob <- utils::getFromNamespace("get.current.chob", "quantmod")
  lchob <- get_chob()
  if (is.null(lchob)) {
    stop("addSuperTrendSignals() must be called after an active chartSeries() chart")
  }
  x <- lchob@xdata

  st <- SuperTrend(x, n = n, multiplier = multiplier,
                   atr_method = atr_method)
  hi <- as.numeric(quantmod::Hi(x))
  lo <- as.numeric(quantmod::Lo(x))
  parts <- signal_markers(st, hi, lo, offset = offset)

  # Same NSE workaround as addSuperTrend() (see R/addSuperTrend.R:86-97
  # for the explanatory comment block). Bind the xts into a fresh
  # environment whose parent is .GlobalEnv, then evaluate the addTA
  # call there. plot() must be called on each chobTA so the layer
  # renders from inside this function frame.
  ta_env <- new.env(parent = .GlobalEnv)
  assign("buy_markers",  parts$buy,  envir = ta_env)
  assign("sell_markers", parts$sell, envir = ta_env)

  ta_buy <- base::eval (
    bquote(quantmod::addTA(buy_markers, on = .(on), type = "p",
                           pch = .(pch[1L]), col = .(col[1L]),
                           bg = .(col[1L]), cex = .(cex))),
    envir = ta_env
  )
  ta_sell <- base::eval (
    bquote(quantmod::addTA(sell_markers, on = .(on), type = "p",
                           pch = .(pch[2L]), col = .(col[2L]),
                           bg = .(col[2L]), cex = .(cex))),
    envir = ta_env
  )
  plot(ta_buy)
  plot(ta_sell)
  invisible(NULL)
}
```

(Reminder from the header note: the cosmetic space before `(` on `base::eval` is harmless — R parses it identically to the no-space form. When you type the actual implementation, match the existing repo style and remove the space.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `R -q -e "devtools::test(filter = 'addSuperTrendSignals')"`
Expected: all 7 test_that blocks pass.

- [ ] **Step 5: Run the full test suite to confirm no regressions**

Run: `R -q -e "devtools::test()"`
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add R/addSuperTrendSignals.R tests/testthat/test-addSuperTrendSignals.R
git commit -m "Add addSuperTrendSignals() overlay for buy/sell triangles"
```

---

### Task 3: Wire `signals = TRUE` flag into `addSuperTrend()` (TDD)

`addSuperTrend()` gains a default-on `signals` flag plus four pass-through customization arguments. When `signals = TRUE`, after drawing the bicolor line it calls `addSuperTrendSignals()` with the same `n`, `multiplier`, `atr_method` plus the `signals_*` overrides.

**Files:**
- Modify: `R/addSuperTrend.R` (function signature, validation block, body)
- Modify: `tests/testthat/test-addSuperTrend.R` (add tests for the new flag)

- [ ] **Step 1: Write the new failing tests**

Append to `tests/testthat/test-addSuperTrend.R`:

```r
test_that("addSuperTrend with signals = TRUE (default) draws without error", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample)
  expect_no_error(addSuperTrend())  # default signals = TRUE
})

test_that("addSuperTrend with signals = FALSE preserves v0.2.1 behavior", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample)
  expect_no_error(addSuperTrend(signals = FALSE))
})

test_that("addSuperTrend rejects non-logical signals", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample)
  expect_error(addSuperTrend(signals = "yes"),
               "signals must be a single TRUE or FALSE")
  expect_error(addSuperTrend(signals = c(TRUE, FALSE)),
               "signals must be a single TRUE or FALSE")
  expect_error(addSuperTrend(signals = NA),
               "signals must be a single TRUE or FALSE")
})

test_that("addSuperTrend forwards signals_col to the marker layer", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample)
  expect_no_error(
    addSuperTrend(signals_col = c("forestgreen", "firebrick"))
  )
})

test_that("addSuperTrend rejects bad signals_col when signals = TRUE", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample)
  expect_error(addSuperTrend(signals_col = "blue"),
               "col must be a length-2 character vector")
})

test_that("addSuperTrend ignores signals_* args when signals = FALSE", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  quantmod::chartSeries(spy_sample)
  # Bad signals_col would error if validated, but signals = FALSE
  # short-circuits the call so the argument is never used.
  expect_no_error(addSuperTrend(signals = FALSE, signals_col = "bogus"))
})
```

- [ ] **Step 2: Run new tests to verify they fail**

Run: `R -q -e "devtools::test(filter = 'addSuperTrend')"`
Expected: the 6 new tests fail (function does not yet accept `signals` / `signals_col`); existing tests still pass.

- [ ] **Step 3: Update `addSuperTrend()` signature, validation, and body**

In `R/addSuperTrend.R`, replace the entire `addSuperTrend` function definition (currently at lines 58-115) with:

```r
addSuperTrend <- function(n = 10, multiplier = 3,
                          atr_method = c("wilder", "sma", "ema"),
                          col = c("#26a69a", "#ef5350"),
                          lwd = 2, on = 1,
                          signals = TRUE,
                          signals_col = col,
                          signals_pch = c(24, 25),
                          signals_cex = 1.2,
                          signals_offset = 0.015) {
  atr_method <- match.arg(atr_method)
  if (!is.character(col) || length(col) != 2L ||
      anyNA(col) || any(!nzchar(col))) {
    stop("col must be a length-2 character vector: c(uptrend, downtrend)")
  }
  if (!is.numeric(lwd) || length(lwd) != 1L || !is.finite(lwd) || lwd <= 0) {
    stop("lwd must be a positive number")
  }
  if (!is.numeric(on) || length(on) != 1L || !is.finite(on) ||
      on != as.integer(on) || on < 1) {
    stop("on must be a positive integer panel index")
  }
  if (!is.logical(signals) || length(signals) != 1L || is.na(signals)) {
    stop("signals must be a single TRUE or FALSE")
  }

  get_chob <- utils::getFromNamespace("get.current.chob", "quantmod")
  lchob <- get_chob()
  if (is.null(lchob)) {
    stop("addSuperTrend() must be called after an active chartSeries() chart")
  }
  x <- lchob@xdata

  st <- SuperTrend(x, n = n, multiplier = multiplier,
                   atr_method = atr_method)
  parts <- split_by_trend(st)

  # quantmod::addTA uses NSE: it captures the call expression and
  # re-evaluates the data symbol at draw time. From a package namespace
  # the local variable isn't found, so the line silently fails to
  # render. Workaround: bind the xts into a fresh environment whose
  # parent is .GlobalEnv, then evaluate the addTA call there. addTA's
  # NSE finds the symbol; the user's workspace stays clean.
  #
  # Two single-column overlays (one per color) are required because
  # quantmod's chartTA renderer can't be coaxed into per-column colors
  # for a multi-column overlay. plot() must be called on each chobTA
  # so each layer actually renders (addTA from inside a function frame
  # returns a chobTA without drawing it).
  ta_env <- new.env(parent = .GlobalEnv)
  assign("up_line",   parts$up,   envir = ta_env)
  assign("down_line", parts$down, envir = ta_env)

  ta_up <- base::eval (
    bquote(quantmod::addTA(up_line, on = .(on), type = "l",
                           col = .(col[1L]), lwd = .(lwd))),
    envir = ta_env
  )
  ta_down <- base::eval (
    bquote(quantmod::addTA(down_line, on = .(on), type = "l",
                           col = .(col[2L]), lwd = .(lwd))),
    envir = ta_env
  )
  plot(ta_up)
  plot(ta_down)

  if (isTRUE(signals)) {
    addSuperTrendSignals(n = n, multiplier = multiplier,
                         atr_method = atr_method,
                         col = signals_col, pch = signals_pch,
                         cex = signals_cex, offset = signals_offset,
                         on = on)
  }

  invisible(NULL)
}
```

(Same reminder: when typing into the source file, drop the cosmetic space before `(` on each `base::eval` line. The existing `addSuperTrend.R` already does this — match its style.)

Also update the roxygen block above the function (lines 24-57) to document the new arguments. Replace it with:

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
#' \code{trend == -1} (downtrend). The two segments meet but do not
#' connect across trend-flip bars (each segment lives on a different
#' band), producing the canonical SuperTrend visual break.
#'
#' By default, buy/sell signal triangles are also drawn at every trend
#' flip (\code{signals = TRUE}); pass \code{signals = FALSE} to suppress
#' them.
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
#' @param signals Logical. If \code{TRUE} (default), draw buy/sell
#'   triangles via \code{\link{addSuperTrendSignals}} after the line.
#' @param signals_col,signals_pch,signals_cex,signals_offset Passed
#'   through to \code{\link{addSuperTrendSignals}} when
#'   \code{signals = TRUE}. \code{signals_col} defaults to \code{col}
#'   so triangles match the line by default.
#'
#' @return Invisibly \code{NULL}; called for the side effect of drawing
#'   overlay layers on the active chart.
#'
#' @examples
#' if (interactive()) {
#'   data(spy_sample)
#'   quantmod::chartSeries(spy_sample)
#'   addSuperTrend()
#' }
#'
#' @export
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `R -q -e "devtools::test(filter = 'addSuperTrend')"`
Expected: all tests pass (existing + 6 new).

- [ ] **Step 5: Commit**

```bash
git add R/addSuperTrend.R tests/testthat/test-addSuperTrend.R
git commit -m "Wire signals = TRUE flag into addSuperTrend()"
```

---

### Task 4: Wire `signals = TRUE` flag into `chartSuperTrend()` (TDD)

`chartSuperTrend()` is the convenience wrapper that calls `chartSeries()` then `addSuperTrend()`. It already passes `n`, `multiplier`, `atr_method`, `col` through to `addSuperTrend()`. Add the same `signals*` pass-through arguments.

**Files:**
- Modify: `R/chartSuperTrend.R` (full function and roxygen)
- Modify: `tests/testthat/test-addSuperTrend.R` (add chartSuperTrend tests)

- [ ] **Step 1: Write the failing tests**

Append to `tests/testthat/test-addSuperTrend.R`:

```r
test_that("chartSuperTrend signals = FALSE is accepted and runs", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  expect_no_error(chartSuperTrend(spy_sample, signals = FALSE))
})

test_that("chartSuperTrend forwards signals_col to the marker layer", {
  skip_on_cran()
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  data(spy_sample, package = "supertrend")
  expect_no_error(
    chartSuperTrend(spy_sample,
                    signals_col = c("forestgreen", "firebrick"))
  )
})
```

- [ ] **Step 2: Run new tests to verify they fail**

Run: `R -q -e "devtools::test(filter = 'addSuperTrend')"`
Expected: the 2 new chartSuperTrend tests fail (`signals` / `signals_col` not yet accepted).

- [ ] **Step 3: Update `chartSuperTrend()`**

Replace the entire `R/chartSuperTrend.R` content with:

```r
#' Chart a Series with SuperTrend Overlay
#'
#' Convenience wrapper that draws a \code{\link[quantmod]{chartSeries}}
#' price chart and overlays the bicolor SuperTrend line plus buy/sell
#' signal triangles in one call.
#'
#' @param x An \code{xts} OHLC series.
#' @param ... Additional arguments passed to
#'   \code{\link[quantmod]{chartSeries}} (e.g., \code{theme}, \code{type},
#'   \code{subset}, \code{TA}).
#' @param name Chart title. Defaults to the deparsed input expression.
#' @param n,multiplier,atr_method,col Passed through to
#'   \code{\link{addSuperTrend}}. \code{col} is a length-2 character
#'   vector: uptrend color, downtrend color.
#' @param signals Logical. If \code{TRUE} (default), draw buy/sell
#'   triangles via \code{\link{addSuperTrendSignals}}.
#' @param signals_col,signals_pch,signals_cex,signals_offset Passed
#'   through to \code{\link{addSuperTrendSignals}} when
#'   \code{signals = TRUE}.
#'
#' @return Invisibly \code{NULL}; called for the side effect of drawing.
#'
#' @examples
#' if (interactive()) {
#'   data(spy_sample)
#'   chartSuperTrend(spy_sample)
#' }
#'
#' @export
chartSuperTrend <- function(x, ..., name = deparse(substitute(x)),
                            n = 10, multiplier = 3,
                            atr_method = c("wilder", "sma", "ema"),
                            col = c("#26a69a", "#ef5350"),
                            signals = TRUE,
                            signals_col = col,
                            signals_pch = c(24, 25),
                            signals_cex = 1.2,
                            signals_offset = 0.015) {
  atr_method <- match.arg(atr_method)
  quantmod::chartSeries(x, name = name, ...)
  addSuperTrend(n = n, multiplier = multiplier,
                atr_method = atr_method, col = col,
                signals = signals,
                signals_col = signals_col,
                signals_pch = signals_pch,
                signals_cex = signals_cex,
                signals_offset = signals_offset)
  invisible(NULL)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `R -q -e "devtools::test(filter = 'addSuperTrend')"`
Expected: all tests pass (existing + 2 new).

- [ ] **Step 5: Commit**

```bash
git add R/chartSuperTrend.R tests/testthat/test-addSuperTrend.R
git commit -m "Wire signals = TRUE flag into chartSuperTrend()"
```

---

### Task 5: Regenerate roxygen docs and NAMESPACE

`devtools::document()` regenerates `man/*.Rd` files from the roxygen blocks and updates `NAMESPACE` with the new `export(addSuperTrendSignals)` line.

**Files:**
- Regenerate: `NAMESPACE`
- Regenerate: `man/addSuperTrend.Rd`
- Regenerate: `man/chartSuperTrend.Rd`
- Create: `man/addSuperTrendSignals.Rd`

- [ ] **Step 1: Run document()**

Run: `R -q -e "devtools::document()"`
Expected: console output shows `man/addSuperTrendSignals.Rd` written, `man/addSuperTrend.Rd` and `man/chartSuperTrend.Rd` updated, `NAMESPACE` updated.

- [ ] **Step 2: Verify NAMESPACE has the new export**

Run: `grep -n addSuperTrendSignals /home/lab/tmp/supertrend/NAMESPACE`
Expected output includes: `export(addSuperTrendSignals)`

- [ ] **Step 3: Verify the new man page exists**

Run: `ls /home/lab/tmp/supertrend/man/addSuperTrendSignals.Rd`
Expected: file path printed (no error).

- [ ] **Step 4: Commit**

```bash
git add NAMESPACE man/addSuperTrend.Rd man/chartSuperTrend.Rd man/addSuperTrendSignals.Rd
git commit -m "Regenerate roxygen docs and NAMESPACE for signal triangles"
```

---

### Task 6: Update README.md

Add a short note in the chart section that signal triangles render by default and how to suppress them.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read the current README to find the chart example**

Run: `head -120 /home/lab/tmp/supertrend/README.md`

Locate the section that demonstrates `chartSuperTrend()` or `addSuperTrend()` (likely a fenced R block with `chartSuperTrend(spy_sample)`).

- [ ] **Step 2: Insert a paragraph immediately after that fenced R block**

Insert this text after the existing `chartSuperTrend(spy_sample)` example block, before any subsequent section header:

````markdown
The chart now also marks every trend flip with a TradingView-style
triangle: a green up-triangle below the bar where the trend turns up
(buy signal), and a red down-triangle above the bar where it turns
down (sell signal). To suppress them, pass `signals = FALSE`:

```r
chartSuperTrend(spy_sample, signals = FALSE)
```

You can also draw the triangles independently after a chart has been
rendered:

```r
chartSeries(spy_sample)
addSuperTrend(signals = FALSE)
addSuperTrendSignals()
```
````

- [ ] **Step 3: Visually verify the file**

Run: `head -150 /home/lab/tmp/supertrend/README.md`
Expected: the new paragraph appears in the chart section, fenced code blocks render correctly (no broken backticks).

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "README: document signal triangles and signals = FALSE override"
```

---

### Task 7: Update NEWS.md

Add a `# supertrend 0.3.0` heading at the top describing the additive change.

**Files:**
- Modify: `NEWS.md`

- [ ] **Step 1: Prepend a new section**

Insert at the very top of `NEWS.md` (above the existing `# supertrend 0.2.1` heading):

```markdown
# supertrend 0.3.0

* New exported function `addSuperTrendSignals()`: draws TradingView-style
  buy/sell triangles at every SuperTrend trend flip on the active chart.
  Green up-triangle below the Low of flip-up bars; red down-triangle
  above the High of flip-down bars.

* `addSuperTrend()` and `chartSuperTrend()` gain a `signals = TRUE`
  argument (default ON) that calls `addSuperTrendSignals()` after the
  bicolor line. Pass `signals = FALSE` to restore the v0.2.1 line-only
  output.

* New `signals_col`, `signals_pch`, `signals_cex`, `signals_offset`
  pass-through arguments on `addSuperTrend()` and `chartSuperTrend()`
  for customizing the marker layer. `signals_col` defaults to `col`,
  so triangles match the bicolor line by default.

```

If Task 0 selected the `pch = c(17, 25)` fallback instead of the `c(24, 25)` + `bg` default, append a one-line note to the first bullet:

```
  Marker shapes default to `pch = c(17, 25)` (filled triangles) for
  compatibility with the installed quantmod version.
```

- [ ] **Step 2: Verify the file**

Run: `head -25 /home/lab/tmp/supertrend/NEWS.md`
Expected: new 0.3.0 section followed by the 0.2.1 section.

- [ ] **Step 3: Commit**

```bash
git add NEWS.md
git commit -m "NEWS: 0.3.0 entry for signal triangles"
```

---

### Task 8: Bump version in DESCRIPTION

**Files:**
- Modify: `DESCRIPTION` (Version line)

- [ ] **Step 1: Bump the version**

Edit `DESCRIPTION` — change `Version: 0.2.1` to `Version: 0.3.0`.

- [ ] **Step 2: Verify**

Run: `grep -n ^Version /home/lab/tmp/supertrend/DESCRIPTION`
Expected: `Version: 0.3.0` on the version line (line 4 in v0.2.1).

- [ ] **Step 3: Commit**

```bash
git add DESCRIPTION
git commit -m "Bump version to 0.3.0"
```

---

### Task 9: Final R CMD check, full test run, and visual confirmation

Belt-and-braces verification before declaring the branch done.

- [ ] **Step 1: Run the full test suite**

Run: `R -q -e "devtools::test()"`
Expected: 0 failures. New tests added across Tasks 1-4: 7 (signal_markers) + 7 (addSuperTrendSignals) + 6 (addSuperTrend signals) + 2 (chartSuperTrend signals) = 22 new test_that blocks.

- [ ] **Step 2: Build the source tarball**

```bash
cd /home/lab/tmp
R CMD build /home/lab/tmp/supertrend
```

Expected: produces `supertrend_0.3.0.tar.gz`.

- [ ] **Step 3: Run R CMD check --as-cran**

```bash
R CMD check --as-cran supertrend_0.3.0.tar.gz
```

Expected: 0 errors, 0 warnings. Notes are acceptable but inspect each one — they should match the notes the v0.2.1 build already produces.

If R CMD check reports a documentation mismatch for the new `signals_*` arguments in `addSuperTrend.Rd` or `chartSuperTrend.Rd`, re-run `R -q -e "devtools::document()"` and rebuild. The most common cause is a roxygen `@param` line missing for one of the new arguments.

- [ ] **Step 4: Render a chart to a PDF and visually confirm**

Run:

```bash
Rscript -e 'library(supertrend); pdf("/tmp/v030-chart.pdf", width = 10, height = 6); data(spy_sample); chartSuperTrend(spy_sample); dev.off()'
```

Expected: produces `/tmp/v030-chart.pdf`. Open it and confirm: bicolor line, plus filled green up-triangles below the bar at every trend-up flip and filled red down-triangles above the bar at every trend-down flip. No open outlines (fill must work). The number of triangles should match `sum(supertrend_signals(SuperTrend(spy_sample))[, c("long_entry","short_entry")])`.

- [ ] **Step 5: Clean up**

Run:

```bash
rm /tmp/v030-chart.pdf /home/lab/tmp/supertrend_0.3.0.tar.gz
rm -rf /home/lab/tmp/supertrend.Rcheck
```

- [ ] **Step 6: Final state check**

Run:

```bash
git -C /home/lab/tmp/supertrend status
git -C /home/lab/tmp/supertrend log --oneline -10
```

Expected: working tree clean; the last 8 commits are the ones from Tasks 1-8 plus the spec commit, in order.

Done. The branch is ready for PR / merge.
