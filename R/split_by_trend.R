# Split a SuperTrend output into two trend-masked single-column xts for
# bicolor rendering: `up` carries the supertrend value on +1 bars (NA
# elsewhere), `down` carries it on -1 bars. By construction the two
# never have a non-NA value in the same row.
split_by_trend <- function(st) {
  idx   <- zoo::index(st)
  trend <- as.numeric(st[, "trend"])
  vals  <- as.numeric(st[, "supertrend"])

  up_vals   <- ifelse(!is.na(trend) & trend ==  1L, vals, NA_real_)
  down_vals <- ifelse(!is.na(trend) & trend == -1L, vals, NA_real_)

  up   <- xts::xts(matrix(up_vals,   ncol = 1L,
                          dimnames = list(NULL, "up")),
                   order.by = idx)
  down <- xts::xts(matrix(down_vals, ncol = 1L,
                          dimnames = list(NULL, "down")),
                   order.by = idx)

  list(up = up, down = down)
}
