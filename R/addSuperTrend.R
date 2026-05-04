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
#' @param n,multiplier,atr_method Passed through to
#'   \code{\link{SuperTrend}}.
#' @param col Length-2 character vector of colors. \code{col[1]} is
#'   used for uptrend bars (\code{trend == +1}); \code{col[2]} for
#'   downtrend bars (\code{trend == -1}). Defaults to TradingView's
#'   green / red.
#' @param lwd Line width.
#' @param on Chart panel to draw on. \code{1} = price panel (the
#'   default and the only sensible choice for SuperTrend).
#'
#' @return Invisibly \code{NULL}; called for the side effect of drawing
#'   two overlay layers on the active chart.
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
  parts <- split_by_trend(st)

  # quantmod::addTA uses NSE: it captures the call expression and
  # re-evaluates the data symbol at draw time. From a package namespace
  # the local variable isn't found, so the line silently fails to
  # render. Workaround: bind the xts into a fresh environment whose
  # parent is .GlobalEnv, then evaluate the addTA call there. addTA's
  # NSE finds the symbol; the user's workspace stays clean.
  #
  # Two single-column overlays (one per color) are required because
  # quantmod's chartTA renderer can't be coaxed into per-column colors
  # for a multi-column overlay. plot() must be called on each chobTA
  # so each layer actually renders (addTA from inside a function frame
  # returns a chobTA without drawing it).
  ta_env <- new.env(parent = .GlobalEnv)
  assign("up_line",   parts$up,   envir = ta_env)
  assign("down_line", parts$down, envir = ta_env)

  ta_up <- eval(
    bquote(quantmod::addTA(up_line, on = .(on), type = "l",
                           col = .(col[1L]), lwd = .(lwd))),
    envir = ta_env
  )
  ta_down <- eval(
    bquote(quantmod::addTA(down_line, on = .(on), type = "l",
                           col = .(col[2L]), lwd = .(lwd))),
    envir = ta_env
  )
  plot(ta_up)
  plot(ta_down)
  invisible(NULL)
}
