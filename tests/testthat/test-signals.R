test_that("supertrend_signals returns xts with the expected 0/1 columns", {
  hlc <- make_mixed_hlc()
  st  <- SuperTrend(hlc, n = 10, multiplier = 3)
  sig <- supertrend_signals(st)

  expect_s3_class(sig, "xts")
  expect_equal(colnames(sig),
               c("long_entry", "short_entry", "long_exit", "short_exit"))
  expect_equal(nrow(sig), nrow(st))

  # All values are 0 or 1.
  vals <- unique(as.integer(zoo::coredata(sig)))
  expect_true(all(vals %in% c(0L, 1L)))
})

test_that("supertrend_signals long_entry rows align with short_exit rows", {
  hlc <- make_mixed_hlc()
  sig <- supertrend_signals(SuperTrend(hlc))
  expect_equal(as.integer(sig$long_entry),  as.integer(sig$short_exit))
  expect_equal(as.integer(sig$short_entry), as.integer(sig$long_exit))
})

test_that("supertrend_signals signal counts match number of trend flips", {
  hlc <- make_mixed_hlc()
  st  <- SuperTrend(hlc)
  sig <- supertrend_signals(st)

  trend <- as.numeric(st$trend)
  prev  <- c(NA, head(trend, -1))
  flips_to_up   <- sum(!is.na(prev) & prev == -1 & trend == 1, na.rm = TRUE)
  flips_to_down <- sum(!is.na(prev) & prev == 1  & trend == -1, na.rm = TRUE)

  expect_equal(sum(as.integer(sig$long_entry)),  flips_to_up)
  expect_equal(sum(as.integer(sig$short_entry)), flips_to_down)
})

test_that("supertrend_signals errors on input without trend column", {
  bad <- xts::xts(matrix(1:4, ncol = 2,
                         dimnames = list(NULL, c("foo", "bar"))),
                  order.by = as.Date("2025-01-01") + 0:1)
  expect_error(supertrend_signals(bad),
               "x must be the output of SuperTrend\\(\\)")
})
