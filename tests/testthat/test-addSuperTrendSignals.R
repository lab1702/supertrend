test_that("addSuperTrendSignals runs without error on the sample dataset", {
  skip_on_cran()
  with_chart(expect_no_error(addSuperTrendSignals()))
})

test_that("addSuperTrendSignals errors when no chart is active", {
  if (!is.null(dev.list())) {
    for (d in dev.list()) dev.off()
  }
  expect_error(addSuperTrendSignals())
})

test_that("addSuperTrendSignals rejects bad col vectors", {
  skip_on_cran()
  with_chart({
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
})

test_that("addSuperTrendSignals rejects bad pch vectors", {
  skip_on_cran()
  with_chart({
    expect_error(addSuperTrendSignals(pch = 24),
                 "pch must be a length-2 numeric vector")
    expect_error(addSuperTrendSignals(pch = c(24, 25, 17)),
                 "pch must be a length-2 numeric vector")
    expect_error(addSuperTrendSignals(pch = c(24, NA)),
                 "pch must be a length-2 numeric vector")
    expect_error(addSuperTrendSignals(pch = c("a", "b")),
                 "pch must be a length-2 numeric vector")
  })
})

test_that("addSuperTrendSignals rejects invalid cex", {
  skip_on_cran()
  with_chart({
    expect_error(addSuperTrendSignals(cex = "two"),  "cex must be a positive number")
    expect_error(addSuperTrendSignals(cex = 0),      "cex must be a positive number")
    expect_error(addSuperTrendSignals(cex = -1),     "cex must be a positive number")
    expect_error(addSuperTrendSignals(cex = c(1, 2)),"cex must be a positive number")
  })
})

test_that("addSuperTrendSignals rejects invalid offset", {
  skip_on_cran()
  with_chart({
    expect_error(addSuperTrendSignals(offset = "x"),  "offset must be a positive number")
    expect_error(addSuperTrendSignals(offset = 0),    "offset must be a positive number")
    expect_error(addSuperTrendSignals(offset = -1),   "offset must be a positive number")
  })
})

test_that("addSuperTrendSignals rejects invalid on", {
  skip_on_cran()
  with_chart({
    expect_error(addSuperTrendSignals(on = 0),    "on must be a positive integer panel index")
    expect_error(addSuperTrendSignals(on = -1),   "on must be a positive integer panel index")
    expect_error(addSuperTrendSignals(on = 1.5),  "on must be a positive integer panel index")
    expect_error(addSuperTrendSignals(on = "1"),  "on must be a positive integer panel index")
  })
})
