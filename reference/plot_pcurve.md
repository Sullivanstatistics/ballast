# Plot p-value curves over a continuous perturbation

Draws the p-value against the parameter for every family of rows that
carries a `param` value (from
[`stress_tipping()`](https://sullivanstatistics.github.io/ballast/reference/stress_tipping.md)
or
[`stress_curve()`](https://sullivanstatistics.github.io/ballast/reference/stress_curve.md)):
one line per family, the alpha reference line, the anchor point (the row
of `kind = "alternative"`, usually the unshifted analysis) emphasised,
and a dotted vertical line at each interpolated crossing with its value.

## Usage

``` r
plot_pcurve(
  rows,
  alpha = NULL,
  xlab = "Perturbation",
  ylab = "p-value",
  log_p = FALSE
)
```

## Arguments

- rows:

  A `stress_rows` data frame or `stress_census`; rows without a `param`
  are ignored.

- alpha:

  Significance level; defaults to the rows' own `alpha`.

- xlab, ylab:

  Axis labels.

- log_p:

  Draw the p-value axis on a log scale.

## Value

A `ggplot` object.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:80), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL)
tp <- stress_tipping(spec, deltas = c(0, -4, -8), m = 3)
if (requireNamespace("ggplot2", quietly = TRUE)) plot_pcurve(tp)
```
