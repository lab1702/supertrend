# supertrend 0.4.0

## Breaking changes

* Removed the `signals_col`, `signals_pch`, `signals_cex`, and
  `signals_offset` pass-through arguments from `addSuperTrend()` and
  `chartSuperTrend()`. Signal triangles now always use `col` for their
  colors and the `addSuperTrendSignals()` defaults for everything else.
  Code that needs custom marker style should pass `signals = FALSE` and
  call `addSuperTrendSignals()` directly after the line.

## Improvements

* `addSuperTrend(signals = TRUE)` and `chartSuperTrend()` now compute
  the SuperTrend object once instead of twice. No user-visible change.
* `?SuperTrend` documents the trend seed convention: the first valid
  bar is seeded `trend = +1`, matching Pine Script.
* `addSuperTrend()` and `addSuperTrendSignals()` now reject any `on`
  value other than `1`. Previously, values like `on = 2` were accepted
  by the validator but produced an off-screen overlay because
  SuperTrend values live on the price scale. The error message is
  explicit, and the docs now state the constraint.
* `?addSuperTrend` documents that single-bar trend segments render no
  line (only the signal triangle), since `type = "l"` draws nothing
  for an isolated non-NA point. Affects rare configurations on noisy
  intraday series with small multipliers.

# supertrend 0.3.0

* New exported function `addSuperTrendSignals()`: draws TradingView-style
  buy/sell triangles at every SuperTrend trend flip on the active chart.
  Green up-triangle below the Low of flip-up bars; red down-triangle
  above the High of flip-down bars.

* `addSuperTrend()` and `chartSuperTrend()` gain a `signals = TRUE`
  argument (default ON) that calls `addSuperTrendSignals()` after the
  bicolor line. Pass `signals = FALSE` to restore the v0.2.1 line-only
  output.

* New `signals_col`, `signals_pch`, `signals_cex`, `signals_offset`
  pass-through arguments on `addSuperTrend()` and `chartSuperTrend()`
  for customizing the marker layer. `signals_col` defaults to `col`,
  so triangles match the bicolor line by default.

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
