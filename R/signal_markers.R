# Build buy/sell marker layers from a SuperTrend result. Returns a list
# of two single-column xts:
#   buy[i]  = lo[i] - pad  on bars where trend flips -1 -> +1, NA elsewhere
#   sell[i] = hi[i] + pad  on bars where trend flips +1 -> -1, NA elsewhere
# pad = offset * (max(hi) - min(lo)) — a fraction of the visible panel
# range so markers sit just outside the candle. By construction, buy
# and sell never share a non-NA row (a flip is up XOR down).
#
# st: xts returned by SuperTrend() (must contain a `trend` column).
# hi, lo: numeric vectors of High and Low aligned to st (same length).
# offset: positive numeric — fraction of panel range used as padding.
signal_markers <- function(st, hi, lo, offset) {
  trend <- as.numeric(st[, "trend"])
  prev  <- c(NA_real_, utils::head(trend, -1))

  flip_up   <- !is.na(prev) & !is.na(trend) & prev == -1 & trend == 1
  flip_down <- !is.na(prev) & !is.na(trend) & prev == 1  & trend == -1

  panel_range <- max(hi, na.rm = TRUE) - min(lo, na.rm = TRUE)
  pad <- offset * panel_range

  buy_y  <- ifelse(flip_up,   lo - pad, NA_real_)
  sell_y <- ifelse(flip_down, hi + pad, NA_real_)

  idx <- zoo::index(st)
  list(
    buy  = xts::xts(matrix(buy_y,  ncol = 1L,
                           dimnames = list(NULL, "buy")),
                    order.by = idx),
    sell = xts::xts(matrix(sell_y, ncol = 1L,
                           dimnames = list(NULL, "sell")),
                    order.by = idx)
  )
}
