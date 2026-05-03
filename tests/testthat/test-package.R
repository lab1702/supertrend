test_that("package loads without error", {
  expect_true(is.character(as.character(packageVersion("supertrend"))))
})
