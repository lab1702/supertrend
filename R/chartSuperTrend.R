#' Chart a Series with SuperTrend Overlay
#'
#' Convenience wrapper that draws a \code{\link[quantmod]{chartSeries}}
#' price chart and overlays the bicolor SuperTrend line in one call.
#'
#' @param x An \code{xts} OHLC series.
#' @param ... Additional arguments passed to
#'   \code{\link[quantmod]{chartSeries}} (e.g., \code{theme}, \code{type},
#'   \code{subset}, \code{TA}).
#' @param name Chart title. Defaults to the deparsed input expression.
#' @param n,multiplier,atr_method,col Passed through to
#'   \code{\link{addSuperTrend}}. \code{col} is a length-2 character
#'   vector: uptrend color, downtrend color.
#'
#' @return Invisibly \code{NULL}; called for the side effect of drawing.
#'
#' @examples
#' if (interactive()) {
#'   data(spy_sample)
#'   chartSuperTrend(spy_sample)
#' }
#'
#' @export
chartSuperTrend <- function(x, ..., name = deparse(substitute(x)),
                            n = 10, multiplier = 3,
                            atr_method = c("wilder", "sma", "ema"),
                            col = c("#26a69a", "#ef5350")) {
  atr_method <- match.arg(atr_method)
  quantmod::chartSeries(x, name = name, ...)
  addSuperTrend(n = n, multiplier = multiplier,
                atr_method = atr_method, col = col)
  invisible(NULL)
}
