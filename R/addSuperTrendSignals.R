#' Add Buy/Sell Signal Triangles to an Active 'quantmod' Chart
#'
#' Adds TradingView-style trend-flip markers to the price panel of the
#' currently active \code{\link[quantmod]{chartSeries}} chart. A green
#' up-triangle is drawn just below the Low of every bar where the
#' SuperTrend flips to uptrend; a red down-triangle is drawn just
#' above the High of every bar where it flips to downtrend.
#'
#' @param n,multiplier,atr_method Passed through to
#'   \code{\link{SuperTrend}}.
#' @param col Length-2 character vector of colors. \code{col[1]} is
#'   used for buy markers (flip-up); \code{col[2]} for sell markers
#'   (flip-down). Defaults to TradingView's green / red.
#' @param pch Length-2 numeric vector of plot characters.
#'   \code{pch[1]} for buy markers, \code{pch[2]} for sell markers.
#'   Defaults to \code{c(24, 25)} (filled up-triangle, filled
#'   down-triangle).
#' @param cex Positive numeric. Marker size multiplier. Defaults to 1.2.
#' @param offset Positive numeric. Fraction of the data price range
#'   used to pad markers off the candle so the triangle never overlaps
#'   the wick. Defaults to 0.015 (1.5\%).
#' @param on Chart panel to draw on. \code{1} = price panel (the only
#'   sensible choice for SuperTrend signals).
#'
#' @return Invisibly \code{NULL}; called for the side effect of drawing
#'   two overlay layers on the active chart.
#'
#' @examples
#' if (interactive()) {
#'   data(spy_sample)
#'   quantmod::chartSeries(spy_sample)
#'   addSuperTrendSignals()
#' }
#'
#' @export
addSuperTrendSignals <- function(n = 10, multiplier = 3,
                                 atr_method = c("wilder", "sma", "ema"),
                                 col = c("#26a69a", "#ef5350"),
                                 pch = c(24, 25),
                                 cex = 1.2,
                                 offset = 0.015,
                                 on = 1) {
  atr_method <- match.arg(atr_method)
  .check_col2(col, "c(buy, sell)")
  if (!is.numeric(pch) || length(pch) != 2L || anyNA(pch)) {
    stop("pch must be a length-2 numeric vector: c(buy, sell)")
  }
  .check_pos_num(cex, "cex")
  .check_pos_num(offset, "offset")
  .check_pos_int(on, "on")

  get_chob <- utils::getFromNamespace("get.current.chob", "quantmod")
  lchob <- get_chob()
  if (is.null(lchob)) {
    stop("addSuperTrendSignals() must be called after an active chartSeries() chart")
  }
  x <- lchob@xdata

  st <- SuperTrend(x, n = n, multiplier = multiplier,
                   atr_method = atr_method)
  .draw_signal_markers(st, x, col = col, pch = pch,
                       cex = cex, offset = offset, on = on)
}

# Internal: draw the buy/sell triangle layers from a precomputed
# SuperTrend object. Skips validation and SuperTrend recomputation so
# addSuperTrend() can reuse the st it already has.
.draw_signal_markers <- function(st, x, col, pch, cex, offset, on) {
  hi <- as.numeric(quantmod::Hi(x))
  lo <- as.numeric(quantmod::Lo(x))
  parts <- signal_markers(st, hi, lo, offset = offset)

  .draw_ta(parts$buy,  on = on, type = "p", pch = pch[1L],
           col = col[1L], bg = col[1L], cex = cex)
  .draw_ta(parts$sell, on = on, type = "p", pch = pch[2L],
           col = col[2L], bg = col[2L], cex = cex)
  invisible(NULL)
}
