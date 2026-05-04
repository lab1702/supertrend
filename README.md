# supertrend

SuperTrend technical indicator and signals for [quantmod](https://www.quantmod.com).

The SuperTrend indicator is an ATR-based trailing band that flips trend
direction when price closes through the opposing band. This package
provides a calculation that matches TradingView's `ta.supertrend`,
extracts long/short entry and exit signals on trend flips, and adds a
`quantmod`-idiomatic chart overlay.

## Installation

```r
# install.packages("pak")
pak::pak("lab1702/supertrend")
```

`pak` does not build vignettes on install. To get the vignette
locally — `vignette("supertrend")` — install with `remotes` instead:

```r
# install.packages("remotes")
remotes::install_github("lab1702/supertrend", build_vignettes = TRUE)
```

## Quickstart

```r
library(supertrend)
library(quantmod)

# Use the built-in synthetic dataset (or fetch with getSymbols)
data(spy_sample)

# 1. Compute the indicator
st <- SuperTrend(spy_sample, n = 10, multiplier = 3)
head(st, 15)

# 2. Plot it
chartSuperTrend(spy_sample)

# 3. Extract signals
sig <- supertrend_signals(st)
sig[rowSums(sig) > 0, ]
```

The chart now also marks every trend flip with a TradingView-style
triangle: a green up-triangle below the bar where the trend turns up
(buy signal), and a red down-triangle above the bar where it turns
down (sell signal). To suppress them, pass `signals = FALSE`:

```r
chartSuperTrend(spy_sample, signals = FALSE)
```

You can also draw the triangles independently after a chart has been
rendered:

```r
chartSeries(spy_sample)
addSuperTrend(signals = FALSE)
addSuperTrendSignals()
```

## API

| Function | Purpose |
|---|---|
| `SuperTrend(HLC, n, multiplier, atr_method)` | Compute the indicator. Returns an xts with `supertrend`, `trend`, `upper_band`, `lower_band`. |
| `supertrend_signals(st)` | Extract long/short entry/exit events on trend flips. |
| `addSuperTrend(...)` | quantmod overlay — call after `chartSeries()`. |
| `chartSuperTrend(x, ...)` | One-liner: chart and overlay in one call. |

See `vignette("supertrend")` for a full walkthrough.

## Roadmap

- v0.3.0: ggplot2-based visualization function for non-quantmod workflows.

## License

MIT
