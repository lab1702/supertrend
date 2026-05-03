#' SuperTrend Trading Signals
#'
#' Extracts long/short entry and exit events from the output of
#' \code{\link{SuperTrend}}. A trend flip from \code{-1} to \code{+1}
#' produces a long entry (and a short exit on the same bar). A flip
#' from \code{+1} to \code{-1} produces a short entry (and a long
#' exit). Entry and exit columns are exposed separately because most
#' backtesting frameworks consume them as distinct rules.
#'
#' @param x The \code{xts} object returned by \code{\link{SuperTrend}}.
#'   Must contain a \code{trend} column.
#'
#' @return An \code{xts} aligned to \code{x} with four integer 0/1
#'   columns: \code{long_entry}, \code{short_entry}, \code{long_exit},
#'   \code{short_exit}. Warm-up rows and the first row are 0.
#'
#' @examples
#' data(spy_sample)
#' st  <- SuperTrend(spy_sample)
#' sig <- supertrend_signals(st)
#' tail(sig[rowSums(sig) > 0, ])
#'
#' @export
supertrend_signals <- function(x) {
  if (!xts::is.xts(x) || !"trend" %in% colnames(x)) {
    stop("x must be the output of SuperTrend()")
  }

  trend <- as.numeric(x[, "trend"])
  prev  <- c(NA_real_, utils::head(trend, -1))

  flip_up   <- !is.na(prev) & !is.na(trend) & prev == -1 & trend == 1
  flip_down <- !is.na(prev) & !is.na(trend) & prev == 1  & trend == -1

  long_entry  <- as.integer(flip_up)
  short_entry <- as.integer(flip_down)
  long_exit   <- short_entry
  short_exit  <- long_entry

  xts::xts(cbind(long_entry  = long_entry,
                 short_entry = short_entry,
                 long_exit   = long_exit,
                 short_exit  = short_exit),
           order.by = zoo::index(x))
}
