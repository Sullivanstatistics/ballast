# Plot a census: one row per family on the percent-of-base axis

Each counted analysis is a point at its estimate as a percent of the
base estimate, filled by significance; the shaded band is the base
confidence interval on the same axis and the vertical line is the base
estimate. Deletions are drawn in a separate panel from alternative
analyses.

## Usage

``` r
# S3 method for class 'stress_census'
plot(x, ...)
```

## Arguments

- x:

  A `stress_census`.

- ...:

  Unused.

## Value

A `ggplot` object.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:80), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
cen <- stress_census(spec, stress_covariance(spec, c("cs", "ar1h")),
                     stress_loo(spec, by = "RACE"))
if (requireNamespace("ggplot2", quietly = TRUE)) plot(cen)
```
