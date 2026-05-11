#' Synthetic daily OHLC sample data
#'
#' A deterministic synthetic OHLC series resembling one trading year of
#' SPY-style daily bars. Generated locally with a fixed seed so examples,
#' tests, and the vignette work without network access.
#'
#' @format An \code{xts} object with 252 rows and 4 columns:
#' \describe{
#'   \item{Open}{Opening price.}
#'   \item{High}{High of the bar.}
#'   \item{Low}{Low of the bar.}
#'   \item{Close}{Closing price.}
#' }
#' @source Synthetic; see \code{data-raw/build_spy_sample.R} at
#'   \url{https://github.com/lab1702/supertrend} for the generator.
"spy_sample"
