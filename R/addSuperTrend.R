#' Add SuperTrend Overlay to an Active 'quantmod' Chart
#'
#' Adds a SuperTrend line to the price panel of the currently active
#' \code{\link[quantmod]{chartSeries}} chart. Behaves like
#' \code{\link[quantmod]{addBBands}}: must be called after the chart
#' has been drawn, draws on the price panel by default.
#'
#' The line is drawn in two segments -- uptrend bars in \code{col[1]}
#' and downtrend bars in \code{col[2]} -- connected by \code{NA} gaps
#' so colors do not bleed across flip bars.
#'
#' @param n,multiplier,atr_method Passed through to
#'   \code{\link{SuperTrend}}.
#' @param col Length-2 character vector of colors:
#'   \code{c(uptrend, downtrend)}. Defaults to TradingView's
#'   green/red.
#' @param lwd Line width.
#' @param on Chart panel to draw on. \code{1} = price panel (the
#'   default and the only sensible choice for SuperTrend).
#'
#' @return Invisibly, the result of the underlying
#'   \code{\link[quantmod]{addTA}} call.
#'
#' @examples
#' \dontrun{
#'   data(spy_sample)
#'   quantmod::chartSeries(spy_sample, theme = "white")
#'   addSuperTrend()
#' }
#'
#' @export
addSuperTrend <- function(n = 10, multiplier = 3,
                          atr_method = c("wilder", "sma", "ema"),
                          col = c("#26a69a", "#ef5350"),
                          lwd = 2, on = 1) {
  atr_method <- match.arg(atr_method)
  if (!is.character(col) || length(col) != 2L) {
    stop("col must be a length-2 character vector: c(uptrend, downtrend)")
  }

  get_chob <- utils::getFromNamespace("get.current.chob", "quantmod")
  lchob <- get_chob()
  if (is.null(lchob)) {
    stop("addSuperTrend() must be called after an active chartSeries() chart")
  }
  x <- lchob@xdata

  st <- SuperTrend(x, n = n, multiplier = multiplier,
                   atr_method = atr_method)

  st_up <- st[, "supertrend"]
  st_up[as.numeric(st[, "trend"]) != 1] <- NA
  colnames(st_up) <- "SuperTrend.up"

  st_dn <- st[, "supertrend"]
  st_dn[as.numeric(st[, "trend"]) != -1] <- NA
  colnames(st_dn) <- "SuperTrend.dn"

  quantmod::addTA(st_up, on = on, type = "l", col = col[1], lwd = lwd)
  invisible(quantmod::addTA(st_dn, on = on, type = "l", col = col[2], lwd = lwd))
}
