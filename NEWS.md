# supertrend 0.2.1

* Documentation polish for CRAN submission. Examples no longer pin
  `theme = "white"` so quantmod's default theme is used in `?addSuperTrend`,
  `?chartSuperTrend`, the vignette, and the README.
* Replaced `\dontrun{}` with `if (interactive()) { ... }` in roxygen
  examples so example syntax is checked by `R CMD check` while
  rendering still only runs interactively.
* Excluded `.claude/` from the source tarball via `.Rbuildignore`.

# supertrend 0.2.0

## Breaking changes

* `addSuperTrend()` and `chartSuperTrend()` now render the SuperTrend
  line in two colors: `col[1]` (default `"#26a69a"`, green) on uptrend
  bars and `col[2]` (default `"#ef5350"`, red) on downtrend bars.
  `col` must now be a length-2 character vector. Code that passed a
  scalar color in v0.1.0 will need to pass a length-2 vector.

* `addSuperTrend()` now returns `invisible(NULL)` instead of the
  underlying `chobTA` object. Two overlay layers are drawn and there
  is no single object that naturally represents both. Code that
  captured the v0.1.0 return value will silently get `NULL`.

# supertrend 0.1.0

* Initial release.
* `SuperTrend()`: ATR-based trailing-stop trend indicator with
  `wilder` (default), `sma`, and `ema` ATR smoothing methods.
* `supertrend_signals()`: long/short entry and exit flags on
  trend flips.
* `addSuperTrend()` and `chartSuperTrend()`: quantmod-idiomatic
  chart overlays.
* Built-in `spy_sample` synthetic OHLC dataset.
