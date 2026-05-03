#' SuperTrend Indicator
#'
#' Computes the SuperTrend technical indicator from an OHLC \code{xts}
#' series. The calculation matches the convention used by TradingView's
#' \code{ta.supertrend}: upper and lower bands derived from the median
#' price plus or minus a multiple of the Average True Range (ATR), with
#' bands trailing in the direction of the trend until price closes
#' through them.
#'
#' @param HLC An \code{xts} object containing High, Low, and Close
#'   columns. Validated with \code{\link[quantmod]{has.HLC}}.
#' @param n Integer. ATR period. Defaults to 10 (TradingView default).
#' @param multiplier Numeric. ATR band multiplier. Defaults to 3
#'   (TradingView default).
#' @param atr_method Character. ATR smoothing method. One of
#'   \code{"wilder"} (default, matches TradingView and most charting
#'   platforms), \code{"sma"}, or \code{"ema"}.
#'
#' @return An \code{xts} aligned to the input index with four columns:
#' \describe{
#'   \item{supertrend}{The SuperTrend line value.}
#'   \item{trend}{Trend direction: \code{+1} (uptrend) or \code{-1}
#'     (downtrend).}
#'   \item{upper_band}{Final (trailing) upper band.}
#'   \item{lower_band}{Final (trailing) lower band.}
#' }
#' The first \code{n} rows are \code{NA} (ATR warm-up).
#'
#' @examples
#' data(spy_sample)
#' st <- SuperTrend(spy_sample, n = 10, multiplier = 3)
#' head(st, 15)
#'
#' @export
SuperTrend <- function(HLC, n = 10, multiplier = 3,
                       atr_method = c("wilder", "sma", "ema")) {
  atr_method <- match.arg(atr_method)

  if (!xts::is.xts(HLC)) {
    stop("HLC must be an xts object")
  }
  if (!all(quantmod::has.HLC(HLC))) {
    stop("HLC must contain High, Low, and Close columns")
  }
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1 ||
      n != as.integer(n)) {
    stop("n must be a positive integer")
  }
  if (!is.numeric(multiplier) || length(multiplier) != 1L ||
      is.na(multiplier) || multiplier <= 0) {
    stop("multiplier must be positive")
  }

  hi <- as.numeric(quantmod::Hi(HLC))
  lo <- as.numeric(quantmod::Lo(HLC))
  cl <- as.numeric(quantmod::Cl(HLC))
  N <- length(cl)

  atr_xts <- switch(
    atr_method,
    wilder = TTR::ATR(HLC, n = n, maType = "EMA", wilder = TRUE),
    sma    = TTR::ATR(HLC, n = n, maType = "SMA"),
    ema    = TTR::ATR(HLC, n = n, maType = "EMA")
  )
  atr <- as.numeric(atr_xts[, "atr"])

  hl2 <- (hi + lo) / 2
  upper_basic <- hl2 + multiplier * atr
  lower_basic <- hl2 - multiplier * atr

  upper_final <- rep(NA_real_, N)
  lower_final <- rep(NA_real_, N)
  trend       <- rep(NA_integer_, N)
  st          <- rep(NA_real_, N)

  start <- which(!is.na(atr))[1]
  if (is.na(start) || start >= N) {
    out <- xts::xts(cbind(supertrend = st, trend = trend,
                          upper_band = upper_final,
                          lower_band = lower_final),
                    order.by = zoo::index(HLC))
    return(out)
  }

  upper_final[start] <- upper_basic[start]
  lower_final[start] <- lower_basic[start]
  trend[start]       <- 1L
  st[start]          <- lower_final[start]

  for (i in (start + 1L):N) {
    upper_final[i] <- if (upper_basic[i] < upper_final[i - 1L] ||
                          cl[i - 1L] > upper_final[i - 1L]) {
      upper_basic[i]
    } else {
      upper_final[i - 1L]
    }

    lower_final[i] <- if (lower_basic[i] > lower_final[i - 1L] ||
                          cl[i - 1L] < lower_final[i - 1L]) {
      lower_basic[i]
    } else {
      lower_final[i - 1L]
    }

    trend[i] <- if (cl[i] > upper_final[i - 1L]) {
      1L
    } else if (cl[i] < lower_final[i - 1L]) {
      -1L
    } else {
      trend[i - 1L]
    }

    st[i] <- if (trend[i] == 1L) lower_final[i] else upper_final[i]
  }

  xts::xts(cbind(supertrend = st, trend = trend,
                 upper_band = upper_final, lower_band = lower_final),
           order.by = zoo::index(HLC))
}
