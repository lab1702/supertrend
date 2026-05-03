#' Add SuperTrend Overlay to an Active 'quantmod' Chart
#'
#' Adds a SuperTrend line to the price panel of the currently active
#' \code{\link[quantmod]{chartSeries}} chart. Behaves like
#' \code{\link[quantmod]{addBBands}}: must be called after the chart
#' has been drawn, draws on the price panel by default.
#'
#' The line is drawn with \code{NA} gaps at trend-flip bars so the
#' visual breaks indicate where signals occur.
#'
#' @param n,multiplier,atr_method Passed through to
#'   \code{\link{SuperTrend}}.
#' @param col Line color. Defaults to a medium blue.
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
                          col = "#1976d2",
                          lwd = 2, on = 1) {
  atr_method <- match.arg(atr_method)
  if (!is.character(col) || length(col) != 1L) {
    stop("col must be a single color string")
  }

  get_chob <- utils::getFromNamespace("get.current.chob", "quantmod")
  lchob <- get_chob()
  if (is.null(lchob)) {
    stop("addSuperTrend() must be called after an active chartSeries() chart")
  }
  x <- lchob@xdata

  st <- SuperTrend(x, n = n, multiplier = multiplier,
                   atr_method = atr_method)

  # Insert NA at trend-flip bars so the line breaks visibly at signals.
  trend <- as.numeric(st[, "trend"])
  flips <- c(FALSE, diff(trend) != 0)
  flips[is.na(flips)] <- FALSE
  st_line <- st[, "supertrend"]
  st_line[flips] <- NA
  colnames(st_line) <- "SuperTrend"

  invisible(quantmod::addTA(st_line, on = on, type = "l",
                            col = col, lwd = lwd))
}
