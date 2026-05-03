#' Chart a Series with SuperTrend Overlay
#'
#' Convenience wrapper that draws a \code{\link[quantmod]{chartSeries}}
#' price chart and overlays the SuperTrend line in one call.
#'
#' @param x An \code{xts} OHLC series.
#' @param ... Additional arguments passed to
#'   \code{\link[quantmod]{chartSeries}} (e.g., \code{theme}, \code{type},
#'   \code{subset}, \code{TA}).
#' @param name Chart title. Defaults to the deparsed input expression.
#' @param n,multiplier,atr_method,col Passed through to
#'   \code{\link{addSuperTrend}}.
#'
#' @return Invisibly \code{NULL}; called for the side effect of drawing.
#'
#' @examples
#' \dontrun{
#'   data(spy_sample)
#'   chartSuperTrend(spy_sample, theme = "white")
#' }
#'
#' @export
chartSuperTrend <- function(x, ..., name = deparse(substitute(x)),
                            n = 10, multiplier = 3,
                            atr_method = c("wilder", "sma", "ema"),
                            col = "#1976d2") {
  atr_method <- match.arg(atr_method)
  quantmod::chartSeries(x, name = name, ...)
  addSuperTrend(n = n, multiplier = multiplier,
                atr_method = atr_method, col = col)
  invisible(NULL)
}
