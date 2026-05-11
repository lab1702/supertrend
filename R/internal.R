# Internal helpers shared by the addSuperTrend / addSuperTrendSignals
# overlay functions: argument validators and a wrapper that handles
# quantmod::addTA's NSE-based symbol lookup.

.check_col2 <- function(x, names) {
  if (!is.character(x) || length(x) != 2L ||
      anyNA(x) || any(!nzchar(x))) {
    stop(sprintf("col must be a length-2 character vector: %s", names))
  }
}

.check_pos_num <- function(x, what) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x <= 0) {
    stop(sprintf("%s must be a positive number", what))
  }
}

.check_pos_int <- function(x, what) {
  if (!is.numeric(x) || length(x) != 1L || is.na(x) || !is.finite(x) ||
      x != as.integer(x) || x < 1) {
    stop(sprintf("%s must be a positive integer panel index", what))
  }
}

# quantmod::addTA captures the call expression and re-evaluates the
# data symbol at draw time. From a package namespace a local variable
# isn't found, so the layer silently fails to render. Workaround: bind
# the xts into a fresh environment whose parent is .GlobalEnv, then
# construct an addTA call referring to that bound symbol and evaluate
# there. plot() must be called on each chobTA so the layer renders
# (addTA from inside a function frame returns a chobTA without drawing).
.draw_ta <- function(layer, ...) {
  ta_env <- new.env(parent = .GlobalEnv)
  assign("..layer..", layer, envir = ta_env)
  call <- as.call(c(list(quote(quantmod::addTA), quote(..layer..)),
                    list(...)))
  plot(base::eval(call, envir = ta_env))
  invisible(NULL)
}
