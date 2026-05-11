# Test fixtures for SuperTrend tests.
# All series are deterministic; no randomness, no I/O.

# Run `code` with a hidden PDF device active and a chartSeries() of
# `x` drawn (defaults to the built-in spy_sample fixture). The device
# is closed on exit so tests can be chained without leaking devices.
with_chart <- function(code, x = .spy_sample()) {
  pdf(file = NULL); on.exit(dev.off(), add = TRUE)
  quantmod::chartSeries(x)
  force(code)
}

# Load the built-in spy_sample fixture without polluting the caller's env.
.spy_sample <- function() {
  e <- new.env()
  utils::data("spy_sample", package = "supertrend", envir = e)
  e$spy_sample
}

# 50-bar OHLC where price drifts up, then sharply reverses, then recovers,
# producing at least one downward and one upward trend flip with the default
# n=10, multiplier=3 settings. The first 30 bars are identical to the
# original fixture so frozen regression snapshots (rows 11-30) are unchanged.
make_mixed_hlc <- function() {
  n <- 50
  # First 20 bars: gentle uptrend. Next 10: sharp downtrend. Last 20: recovery.
  close <- c(
    seq(100, 119, length.out = 20),
    seq(118, 95,  length.out = 10),
    seq(96,  120, length.out = 20)
  )
  high <- close + 0.5
  low  <- close - 0.5
  dates <- as.Date("2025-01-01") + seq_len(n) - 1L
  xts::xts(cbind(High = high, Low = low, Close = close), order.by = dates)
}

# Strictly monotonic increasing closes — trend should be +1 after warm-up.
make_monotonic_up_hlc <- function(n = 40) {
  close <- seq(100, 100 + n - 1, length.out = n)
  high <- close + 0.5
  low  <- close - 0.5
  dates <- as.Date("2025-01-01") + seq_len(n) - 1L
  xts::xts(cbind(High = high, Low = low, Close = close), order.by = dates)
}

# Strictly monotonic decreasing closes — trend should be -1 after warm-up
# (and after the initial flip from the +1 seed).
make_monotonic_down_hlc <- function(n = 40) {
  close <- seq(200, 200 - (n - 1), length.out = n)
  high <- close + 0.5
  low  <- close - 0.5
  dates <- as.Date("2025-01-01") + seq_len(n) - 1L
  xts::xts(cbind(High = high, Low = low, Close = close), order.by = dates)
}
