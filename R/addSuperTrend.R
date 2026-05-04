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
  if (!is.numeric(lwd) || length(lwd) != 1L || !is.finite(lwd) || lwd <= 0) {
    stop("lwd must be a positive number")
  }
  if (!is.numeric(on) || length(on) != 1L || !is.finite(on) ||
      on != as.integer(on) || on < 1) {
    stop("on must be a positive integer panel index")
  }

  get_chob <- utils::getFromNamespace("get.current.chob", "quantmod")
  lchob <- get_chob()
  if (is.null(lchob)) {
    stop("addSuperTrend() must be called after an active chartSeries() chart")
  }
  x <- lchob@xdata

  st <- SuperTrend(x, n = n, multiplier = multiplier,
                   atr_method = atr_method)

  trend <- as.numeric(st[, "trend"])
  flips <- c(FALSE, diff(trend) != 0)
  flips[is.na(flips)] <- FALSE
  st_line <- st[, "supertrend"]
  st_line[flips] <- NA
  colnames(st_line) <- "SuperTrend"

  # Single-color line in v0.1.0; bicolor by trend (green/red) deferred
  # to v0.2.0 because consecutive quantmod::addTA calls from inside one
  # function frame don't accumulate — only the last TA persists in the
  # chob, defeating the bicolor approach.

  # quantmod::addTA uses NSE: it captures the call expression and
  # re-evaluates the data symbol at draw time. From a package namespace
  # the local variable isn't found, so the line silently fails to render.
  # Workaround: bind the xts to the name "SuperTrend" in a fresh
  # environment whose parent is .GlobalEnv, then eval() the addTA call
  # there. addTA's NSE finds the symbol; the user's workspace stays
  # clean (no .GlobalEnv pollution, so no R CMD check NOTE).
  ta_env <- new.env(parent = .GlobalEnv)
  assign("SuperTrend", st_line, envir = ta_env)

  ta <- eval(
    bquote(quantmod::addTA(SuperTrend, on = .(on), type = "l",
                           col = .(col), lwd = .(lwd))),
    envir = ta_env
  )
  plot(ta)
  invisible(ta)
}
