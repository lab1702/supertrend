test_that("SuperTrend returns xts with the expected columns and length", {
  hlc <- make_mixed_hlc()
  out <- SuperTrend(hlc, n = 10, multiplier = 3)

  expect_s3_class(out, "xts")
  expect_equal(colnames(out),
               c("supertrend", "trend", "upper_band", "lower_band"))
  expect_equal(nrow(out), nrow(hlc))
  expect_equal(zoo::index(out), zoo::index(hlc))
})

test_that("SuperTrend warm-up rows are NA", {
  hlc <- make_mixed_hlc()
  n <- 10
  out <- SuperTrend(hlc, n = n, multiplier = 3)

  # First n rows have NA ATR -> NA SuperTrend
  expect_true(all(is.na(out$supertrend[1:n])))
  expect_true(all(is.na(out$trend[1:n])))

  # Beyond warm-up, no NAs
  expect_false(any(is.na(out$supertrend[(n + 1):nrow(out)])))
  expect_false(any(is.na(out$trend[(n + 1):nrow(out)])))
})

test_that("SuperTrend trend column only contains -1, +1, or NA", {
  hlc <- make_mixed_hlc()
  out <- SuperTrend(hlc, n = 10, multiplier = 3)
  vals <- unique(as.numeric(out$trend))
  expect_true(all(vals %in% c(-1, 1, NA)))
})

test_that("SuperTrend on a strictly rising series stays in uptrend", {
  hlc <- make_monotonic_up_hlc()
  out <- SuperTrend(hlc, n = 10, multiplier = 3)
  trend_after_warmup <- as.numeric(out$trend[11:nrow(out)])
  expect_true(all(trend_after_warmup == 1))
})

test_that("SuperTrend on a strictly falling series flips to downtrend and stays", {
  hlc <- make_monotonic_down_hlc()
  out <- SuperTrend(hlc, n = 10, multiplier = 3)
  # After enough bars for the initial flip, trend must be -1.
  # Conservative: check the last 20 bars.
  tail_trend <- as.numeric(out$trend[(nrow(out) - 19):nrow(out)])
  expect_true(all(tail_trend == -1))
})
