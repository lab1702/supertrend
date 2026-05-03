# Generates data/spy_sample.rda — a deterministic synthetic OHLC series
# resembling daily SPY data. No network access required.
# Re-run this manually after editing; not run during package build.

set.seed(20260503)
n <- 252  # one trading year
dates <- seq(as.Date("2025-01-02"), by = "day", length.out = n)

log_returns <- stats::rnorm(n, mean = 0.0005, sd = 0.012)
close <- 470 * exp(cumsum(log_returns))

intraday_range <- abs(stats::rnorm(n, mean = 0.008, sd = 0.004)) * close
high <- close + stats::runif(n, 0, 1) * intraday_range
low  <- close - stats::runif(n, 0, 1) * intraday_range
open <- low + stats::runif(n, 0, 1) * (high - low)

# Enforce OHLC consistency: high >= max(O,C), low <= min(O,C)
hi <- pmax(open, high, low, close)
lo <- pmin(open, high, low, close)

mat <- cbind(Open = open, High = hi, Low = lo, Close = close)
spy_sample <- xts::xts(mat, order.by = dates)

dir.create("data", showWarnings = FALSE)
save(spy_sample, file = "data/spy_sample.rda",
     version = 2, compress = "xz")
