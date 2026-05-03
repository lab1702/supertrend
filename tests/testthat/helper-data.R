# Test fixtures for SuperTrend tests.
# All series are deterministic; no randomness, no I/O.

# 30-bar OHLC where price drifts up then sharply reverses, producing
# at least one trend flip with the default n=10, multiplier=3 settings.
make_mixed_hlc <- function() {
  n <- 30
  # First 20 bars: gentle uptrend. Last 10: sharp downtrend.
  close <- c(
    seq(100, 119, length.out = 20),
    seq(118, 95,  length.out = 10)
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
