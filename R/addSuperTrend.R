# Split a SuperTrend output into two trend-masked single-column xts for
# bicolor rendering. `up` carries the supertrend value where trend == +1
# (NA elsewhere); `down` carries it where trend == -1. Warm-up rows
# (trend is NA) are NA in both. By construction the two elements never
# have a non-NA value in the same row.
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
#' @param on Chart panel to draw on. \code{1} = price panel (the
#'   default and the only sensible choice for SuperTrend).
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
  .check_pos_int(on, "on")
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
