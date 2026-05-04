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

test_that("signal_markers buy/sell rows align row-for-row with supertrend_signals", {
  hlc <- make_mixed_hlc()
  st  <- SuperTrend(hlc, n = 10, multiplier = 3)
  hi  <- as.numeric(quantmod::Hi(hlc))
  lo  <- as.numeric(quantmod::Lo(hlc))
  sig <- supertrend_signals(st)

  out <- supertrend:::signal_markers(st, hi, lo, offset = 0.015)

  expect_equal(which(!is.na(as.numeric(out$buy))),
               which(as.integer(sig[, "long_entry"]) == 1L))
  expect_equal(which(!is.na(as.numeric(out$sell))),
               which(as.integer(sig[, "short_entry"]) == 1L))
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
