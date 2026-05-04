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
#'   addSuperTrend(signals = FALSE)
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
  if (!is.character(col) || length(col) != 2L ||
      anyNA(col) || any(!nzchar(col))) {
    stop("col must be a length-2 character vector: c(buy, sell)")
  }
  if (!is.numeric(pch) || length(pch) != 2L || anyNA(pch)) {
    stop("pch must be a length-2 numeric vector: c(buy, sell)")
  }
  if (!is.numeric(cex) || length(cex) != 1L || !is.finite(cex) || cex <= 0) {
    stop("cex must be a positive number")
  }
  if (!is.numeric(offset) || length(offset) != 1L ||
      !is.finite(offset) || offset <= 0) {
    stop("offset must be a positive number")
  }
  if (!is.numeric(on) || length(on) != 1L || !is.finite(on) ||
      on != as.integer(on) || on < 1) {
    stop("on must be a positive integer panel index")
  }

  get_chob <- utils::getFromNamespace("get.current.chob", "quantmod")
  lchob <- get_chob()
  if (is.null(lchob)) {
    stop("addSuperTrendSignals() must be called after an active chartSeries() chart")
  }
  x <- lchob@xdata

  st <- SuperTrend(x, n = n, multiplier = multiplier,
                   atr_method = atr_method)
  hi <- as.numeric(quantmod::Hi(x))
  lo <- as.numeric(quantmod::Lo(x))
  parts <- signal_markers(st, hi, lo, offset = offset)

  # Same NSE workaround as addSuperTrend() (see R/addSuperTrend.R
  # comment block in split_by_trend's caller for full explanation).
  # Bind the xts into a fresh environment whose parent is .GlobalEnv,
  # then evaluate the addTA call there. plot() must be called on each
  # chobTA so the layer renders from inside this function frame.
  ta_env <- new.env(parent = .GlobalEnv)
  assign("buy_markers",  parts$buy,  envir = ta_env)
  assign("sell_markers", parts$sell, envir = ta_env)

  ta_buy <- base::eval (
    bquote(quantmod::addTA(buy_markers, on = .(on), type = "p",
                           pch = .(pch[1L]), col = .(col[1L]),
                           bg = .(col[1L]), cex = .(cex))),
    envir = ta_env
  )
  ta_sell <- base::eval (
    bquote(quantmod::addTA(sell_markers, on = .(on), type = "p",
                           pch = .(pch[2L]), col = .(col[2L]),
                           bg = .(col[2L]), cex = .(cex))),
    envir = ta_env
  )
  plot(ta_buy)
  plot(ta_sell)
  invisible(NULL)
}
