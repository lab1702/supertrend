test_that("split_by_trend returns a list of two single-column xts named up/down", {
  hlc <- make_mixed_hlc()
  st <- SuperTrend(hlc, n = 10, multiplier = 3)

  out <- supertrend:::split_by_trend(st)

  expect_type(out, "list")
  expect_named(out, c("up", "down"))
  expect_true(xts::is.xts(out$up))
  expect_true(xts::is.xts(out$down))
  expect_equal(ncol(out$up), 1L)
  expect_equal(ncol(out$down), 1L)
  expect_equal(zoo::index(out$up), zoo::index(st))
  expect_equal(zoo::index(out$down), zoo::index(st))
})

test_that("split_by_trend masks supertrend by trend direction", {
  hlc <- make_mixed_hlc()
  st <- SuperTrend(hlc, n = 10, multiplier = 3)
  out <- supertrend:::split_by_trend(st)

  trend <- as.numeric(st[, "trend"])
  supertrend_vals <- as.numeric(st[, "supertrend"])
  up <- as.numeric(out$up)
  down <- as.numeric(out$down)

  up_rows <- which(trend == 1)
  expect_equal(up[up_rows], supertrend_vals[up_rows])
  expect_true(all(is.na(down[up_rows])))

  down_rows <- which(trend == -1)
  expect_equal(down[down_rows], supertrend_vals[down_rows])
  expect_true(all(is.na(up[down_rows])))
})

test_that("split_by_trend leaves warm-up rows NA in both elements", {
  hlc <- make_mixed_hlc()
  st <- SuperTrend(hlc, n = 10, multiplier = 3)
  out <- supertrend:::split_by_trend(st)

  trend <- as.numeric(st[, "trend"])
  warmup_rows <- which(is.na(trend))
  expect_true(length(warmup_rows) > 0L)
  expect_true(all(is.na(as.numeric(out$up)[warmup_rows])))
  expect_true(all(is.na(as.numeric(out$down)[warmup_rows])))
})

test_that("split_by_trend handles all-uptrend series", {
  hlc <- make_monotonic_up_hlc(n = 40)
  st <- SuperTrend(hlc, n = 10, multiplier = 3)
  out <- supertrend:::split_by_trend(st)

  trend <- as.numeric(st[, "trend"])
  expect_true(all(trend[!is.na(trend)] == 1L))
  expect_true(all(is.na(as.numeric(out$down))))
  non_warmup <- which(!is.na(trend))
  expect_equal(as.numeric(out$up)[non_warmup],
               as.numeric(st[, "supertrend"])[non_warmup])
})

test_that("split_by_trend never has both elements non-NA in the same row", {
  hlc <- make_mixed_hlc()
  st <- SuperTrend(hlc, n = 10, multiplier = 3)
  out <- supertrend:::split_by_trend(st)

  both_set <- !is.na(as.numeric(out$up)) &
              !is.na(as.numeric(out$down))
  expect_true(!any(both_set))
})
