#' Add SuperTrend Overlay to an Active 'quantmod' Chart
#'
#' Adds a bicolor SuperTrend line to the price panel of the currently
#' active \code{\link[quantmod]{chartSeries}} chart. Behaves like
#' \code{\link[quantmod]{addBBands}}: must be called after the chart
#' has been drawn, draws on the price panel by default.
#'
#' The line is drawn in two colors: \code{col[1]} on bars where
#' \code{trend == +1} (uptrend) and \code{col[2]} on bars where
#' \code{trend == -1} (downtrend). The two segments meet but do not
#' connect across trend-flip bars (each segment lives on a different
#' band), producing the canonical SuperTrend visual break.
#'
#' Single-bar trend segments (a flip immediately followed by another
#' flip) render no line, because each segment is then a single non-NA
#' point flanked by NAs and \code{type = "l"} draws nothing. The signal
#' triangle is still drawn at the flip, so the trend change remains
#' visible. This is rare with the default \code{n = 10},
#' \code{multiplier = 3} on daily bars but can occur on noisy intraday
#' series with smaller multipliers.
#'
#' By default, buy/sell signal triangles are also drawn at every trend
#' flip (\code{signals = TRUE}), using \code{col} for the marker
#' colors. Pass \code{signals = FALSE} to suppress them, or call
#' \code{\link{addSuperTrendSignals}} directly for finer control over
#' marker style.
#'
#' @param n,multiplier,atr_method Passed through to
#'   \code{\link{SuperTrend}}.
#' @param col Length-2 character vector of colors. \code{col[1]} is
#'   used for uptrend bars (\code{trend == +1}); \code{col[2]} for
#'   downtrend bars (\code{trend == -1}). Defaults to TradingView's
#'   green / red.
#' @param lwd Line width.
#' @param on Chart panel to draw on. Must be \code{1} (the price
#'   panel); SuperTrend values live on the price scale and would draw
#'   off-screen on any other panel.
#' @param signals Logical. If \code{TRUE} (default), draw buy/sell
#'   triangles via \code{\link{addSuperTrendSignals}} using \code{col}
#'   for marker colors.
#'
#' @return Invisibly \code{NULL}; called for the side effect of drawing
#'   overlay layers on the active chart.
#'
#' @examples
#' if (interactive()) {
#'   data(spy_sample)
#'   quantmod::chartSeries(spy_sample)
#'   addSuperTrend()
#' }
#'
#' @export
addSuperTrend <- function(n = 10, multiplier = 3,
                          atr_method = c("wilder", "sma", "ema"),
                          col = c("#26a69a", "#ef5350"),
                          lwd = 2, on = 1,
                          signals = TRUE) {
  atr_method <- match.arg(atr_method)
  .check_col2(col, "c(uptrend, downtrend)")
  .check_pos_num(lwd, "lwd")
  .check_price_panel(on)
  if (!(isTRUE(signals) || isFALSE(signals))) {
    stop("signals must be a single TRUE or FALSE")
  }

  get_chob <- utils::getFromNamespace("get.current.chob", "quantmod")
  lchob <- get_chob()
  if (is.null(lchob)) {
    stop("addSuperTrend() must be called after an active chartSeries() chart")
  }
  x <- lchob@xdata

  st <- SuperTrend(x, n = n, multiplier = multiplier,
                   atr_method = atr_method)
  parts <- split_by_trend(st)

  .draw_ta(parts$up,   on = on, type = "l", col = col[1L], lwd = lwd)
  .draw_ta(parts$down, on = on, type = "l", col = col[2L], lwd = lwd)

  if (isTRUE(signals)) {
    .draw_signal_markers(st, x, col = col, pch = c(24, 25),
                         cex = 1.2, offset = 0.015, on = on)
  }

  invisible(NULL)
}
