# Build buy/sell triangle layers from a SuperTrend result: one xts per
# direction, non-NA only on flip bars, offset off the candle so the
# triangle sits clear of the wick.
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
