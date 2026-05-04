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
