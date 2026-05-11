test_that("chartSuperTrend runs without error on the sample dataset", {
  skip_on_cran()  # rendering is fragile across CRAN's headless devices
  with_chart(
    expect_no_error(chartSuperTrend(.spy_sample(), n = 10, multiplier = 3))
  )
})

test_that("chartSuperTrend handles an all-uptrend series (down layer all NA)", {
  skip_on_cran()
  with_chart(
    expect_no_error(chartSuperTrend(make_monotonic_up_hlc(n = 50),
                                    n = 10, multiplier = 3))
  )
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
  with_chart(
    expect_no_error(
      chartSuperTrend(.spy_sample(), col = c("forestgreen", "firebrick"))
    )
  )
})

test_that("addSuperTrend rejects a length-1 col (scalar no longer allowed)", {
  skip_on_cran()
  with_chart(
    expect_error(addSuperTrend(col = "blue"),
                 "col must be a length-2 character vector")
  )
})

test_that("addSuperTrend rejects a length-3 col", {
  skip_on_cran()
  with_chart(
    expect_error(addSuperTrend(col = c("a", "b", "c")),
                 "col must be a length-2 character vector")
  )
})

test_that("addSuperTrend rejects non-character col", {
  skip_on_cran()
  with_chart(
    expect_error(addSuperTrend(col = c(1, 2)),
                 "col must be a length-2 character vector")
  )
})

test_that("addSuperTrend rejects col with NA element", {
  skip_on_cran()
  with_chart({
    expect_error(addSuperTrend(col = c("blue", NA)),
                 "col must be a length-2 character vector")
    expect_error(addSuperTrend(col = c(NA_character_, "red")),
                 "col must be a length-2 character vector")
    expect_error(addSuperTrend(col = c(NA_character_, NA_character_)),
                 "col must be a length-2 character vector")
  })
})

test_that("addSuperTrend rejects col with empty-string element", {
  skip_on_cran()
  with_chart({
    expect_error(addSuperTrend(col = c("", "red")),
                 "col must be a length-2 character vector")
    expect_error(addSuperTrend(col = c("blue", "")),
                 "col must be a length-2 character vector")
    expect_error(addSuperTrend(col = c("", "")),
                 "col must be a length-2 character vector")
  })
})

test_that("addSuperTrend rejects invalid lwd", {
  skip_on_cran()
  with_chart({
    expect_error(addSuperTrend(lwd = "two"),  "lwd must be a positive number")
    expect_error(addSuperTrend(lwd = 0),      "lwd must be a positive number")
    expect_error(addSuperTrend(lwd = -1),     "lwd must be a positive number")
  })
})

test_that("addSuperTrend rejects invalid on", {
  skip_on_cran()
  with_chart({
    expect_error(addSuperTrend(on = 0),    "on must be a positive integer panel index")
    expect_error(addSuperTrend(on = -1),   "on must be a positive integer panel index")
    expect_error(addSuperTrend(on = 1.5),  "on must be a positive integer panel index")
    expect_error(addSuperTrend(on = "1"),  "on must be a positive integer panel index")
  })
})

test_that("addSuperTrend with signals = TRUE (default) draws without error", {
  skip_on_cran()
  with_chart(expect_no_error(addSuperTrend()))  # default signals = TRUE
})

test_that("addSuperTrend with signals = FALSE preserves v0.2.1 behavior", {
  skip_on_cran()
  with_chart(expect_no_error(addSuperTrend(signals = FALSE)))
})

test_that("addSuperTrend rejects non-logical signals", {
  skip_on_cran()
  with_chart({
    expect_error(addSuperTrend(signals = "yes"),
                 "signals must be a single TRUE or FALSE")
    expect_error(addSuperTrend(signals = c(TRUE, FALSE)),
                 "signals must be a single TRUE or FALSE")
    expect_error(addSuperTrend(signals = NA),
                 "signals must be a single TRUE or FALSE")
  })
})

test_that("addSuperTrend uses col for signal marker colors", {
  skip_on_cran()
  with_chart(
    expect_no_error(addSuperTrend(col = c("forestgreen", "firebrick")))
  )
})

test_that("chartSuperTrend signals = FALSE is accepted and runs", {
  skip_on_cran()
  with_chart(
    expect_no_error(chartSuperTrend(.spy_sample(), signals = FALSE))
  )
})
