# Find where a p-value curve crosses alpha

For rows that carry a `param` value (from
[`stress_tipping()`](https://sullivanstatistics.github.io/ballast/reference/stress_tipping.md)
or
[`stress_curve()`](https://sullivanstatistics.github.io/ballast/reference/stress_curve.md)),
interpolates linearly between adjacent parameter values to find where
the p-value crosses `alpha`, separately for each family.

## Usage

``` r
tipping_point(rows, alpha = NULL)
```

## Arguments

- rows:

  A `stress_rows` data frame or a `stress_census`.

- alpha:

  Significance level; defaults to the rows' own `alpha`.

## Value

A data frame with one row per family: `family`, `n` points, `param_min`,
`param_max`, `p_min`, `p_max`, `crossing` (the interpolated parameter
value, `NA` when the curve does not cross) and `direction` (`"up"` when
p rises through alpha with increasing parameter, `"down"` otherwise).

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL)
shift_pt3 <- function(d, v) { k <- d$USUBJID == "PT3"; d$FEV1[k] <- d$FEV1[k] + v; d }
tipping_point(stress_curve(spec, values = c(-20, 0, 20), modify = shift_pt3))
#>                                family n param_min param_max     p_min     p_max
#> perturbation curve perturbation curve 3       -20        20 0.1819731 0.4093701
#>                    crossing direction
#> perturbation curve       NA      <NA>
```
