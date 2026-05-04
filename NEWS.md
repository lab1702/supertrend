# supertrend 0.2.0

## Breaking changes

* `addSuperTrend()` and `chartSuperTrend()` now render the SuperTrend
  line in two colors: `col[1]` (default `"#26a69a"`, green) on uptrend
  bars and `col[2]` (default `"#ef5350"`, red) on downtrend bars.
  `col` must now be a length-2 character vector. Code that passed a
  scalar color in v0.1.0 will need to pass a length-2 vector.

# supertrend 0.1.0

* Initial release.
* `SuperTrend()`: ATR-based trailing-stop trend indicator with
  `wilder` (default), `sma`, and `ema` ATR smoothing methods.
* `supertrend_signals()`: long/short entry and exit flags on
  trend flips.
* `addSuperTrend()` and `chartSuperTrend()`: quantmod-idiomatic
  chart overlays.
* Built-in `spy_sample` synthetic OHLC dataset.
