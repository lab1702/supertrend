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

test_that("SuperTrend handles series with exactly n+1 bars (seed-only output)", {
  # Series of exactly 11 bars with n=10 — start index = 11 = N, so the
  # only non-NA output is the seed bar (no flips possible).
  hlc <- make_monotonic_up_hlc(n = 11)
  out <- SuperTrend(hlc, n = 10, multiplier = 3)

  # Rows 1-10 are NA, row 11 is the seeded bar.
  expect_true(all(is.na(out$supertrend[1:10])))
  expect_false(is.na(out$supertrend[11]))
  expect_equal(as.numeric(out$trend[11]), 1)
})

test_that("SuperTrend matches frozen reference values on the mixed fixture", {
  # Regression snapshot. Initial values verified algorithmically against
  # the TradingView ta.supertrend specification. If this test fails after
  # an algorithm or TTR change, regenerate values via:
  #   out <- SuperTrend(make_mixed_hlc(), n=10, multiplier=3)
  # and re-verify against an independent reference before updating.
  out <- SuperTrend(make_mixed_hlc(), n = 10, multiplier = 3)

  expect_equal(as.numeric(out$supertrend[11]), 105.5,    tolerance = 1e-6)
  expect_equal(as.numeric(out$supertrend[15]), 109.5,    tolerance = 1e-6)
  expect_equal(as.numeric(out$supertrend[20]), 114.5,    tolerance = 1e-6)
  expect_equal(as.numeric(out$supertrend[25]), 113.8826, tolerance = 1e-6)
  expect_equal(as.numeric(out$supertrend[30]), 102.3587, tolerance = 1e-6)

  expect_equal(as.numeric(out$trend[11]),  1)
  expect_equal(as.numeric(out$trend[20]),  1)
  expect_equal(as.numeric(out$trend[30]), -1)
})

test_that("SuperTrend rejects non-xts input", {
  expect_error(
    SuperTrend(data.frame(High = 1, Low = 1, Close = 1)),
    "HLC must be an xts object"
  )
})

test_that("SuperTrend rejects xts without HLC columns", {
  bad <- xts::xts(matrix(1:4, ncol = 2,
                         dimnames = list(NULL, c("Foo", "Bar"))),
                  order.by = as.Date("2025-01-01") + 0:1)
  expect_error(
    SuperTrend(bad),
    "HLC must contain High, Low, and Close columns"
  )
})

test_that("SuperTrend rejects invalid n", {
  hlc <- make_mixed_hlc()
  expect_error(SuperTrend(hlc, n = 0),    "n must be a positive integer")
  expect_error(SuperTrend(hlc, n = -1),   "n must be a positive integer")
  expect_error(SuperTrend(hlc, n = 1.5),  "n must be a positive integer")
  expect_error(SuperTrend(hlc, n = "10"), "n must be a positive integer")
})

test_that("SuperTrend rejects non-positive multiplier", {
  hlc <- make_mixed_hlc()
  expect_error(SuperTrend(hlc, multiplier = 0),  "multiplier must be positive")
  expect_error(SuperTrend(hlc, multiplier = -1), "multiplier must be positive")
})

test_that("SuperTrend rejects unknown atr_method via match.arg", {
  hlc <- make_mixed_hlc()
  expect_error(SuperTrend(hlc, atr_method = "bogus"))
})

test_that("SuperTrend produces different results for each atr_method", {
  hlc <- make_mixed_hlc()
  out_w <- SuperTrend(hlc, atr_method = "wilder")
  out_s <- SuperTrend(hlc, atr_method = "sma")
  out_e <- SuperTrend(hlc, atr_method = "ema")

  # Compare a row past warm-up where ATR differences propagate.
  i <- 23
  expect_false(isTRUE(all.equal(as.numeric(out_w$supertrend[i]),
                                as.numeric(out_s$supertrend[i]))))
  expect_false(isTRUE(all.equal(as.numeric(out_w$supertrend[i]),
                                as.numeric(out_e$supertrend[i]))))
  expect_false(isTRUE(all.equal(as.numeric(out_s$supertrend[i]),
                                as.numeric(out_e$supertrend[i]))))
})

test_that("SuperTrend default atr_method is wilder", {
  hlc <- make_mixed_hlc()
  expect_equal(
    as.numeric(SuperTrend(hlc)$supertrend),
    as.numeric(SuperTrend(hlc, atr_method = "wilder")$supertrend)
  )
})

test_that("SuperTrend errors when nrow(HLC) <= n with a clear message", {
  hlc <- make_mixed_hlc()
  short <- hlc[1:5, ]
  expect_error(SuperTrend(short, n = 10),
               "nrow\\(HLC\\) must be greater than n")
  # Boundary case: equal also rejected
  expect_error(SuperTrend(hlc[1:10, ], n = 10),
               "nrow\\(HLC\\) must be greater than n")
})
