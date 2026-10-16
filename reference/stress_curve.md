# Perturbation family: a curve over a continuous data perturbation

Applies a user-supplied modification to the spec's data at each value of
a continuous parameter, refits the pre-specified model and returns one
row per value with the value in `param`. This generalises tipping-point
searches that are not multiple-imputation based: assigning a contested
participant a post-deviation trajectory, shifting one arm's observed
values, moving a baseline definition, and so on. Rows are
`kind = "search"` except the row at `anchor`, which is a counted
alternative.

## Usage

``` r
stress_curve(
  spec,
  values,
  modify,
  family = "perturbation curve",
  anchor = NULL,
  role = "sensitivity",
  cores = 1L
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- values:

  Numeric vector of parameter values.

- modify:

  A function `function(data, value)` returning a data frame in the
  spec's layout. It receives the spec's own data.

- family:

  Family label for the rows.

- anchor:

  The parameter value (if any) that represents an alternative analysis
  in its own right rather than a search point; `NULL` for none.

- role:

  `"sensitivity"` or `"supplementary"`; see
  [`stress_fit()`](https://sullivanstatistics.github.io/ballast/reference/stress_fit.md).

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame, one row per value, with `param` set.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL)
# shift every observed value of one subject on the active arm
shift_pt3 <- function(d, v) { k <- d$USUBJID == "PT3"; d$FEV1[k] <- d$FEV1[k] + v; d }
cv <- stress_curve(spec, values = c(-20, -10, 0, 10, 20), modify = shift_pt3, anchor = 0)
tipping_point(cv)
#>                                family n param_min param_max     p_min     p_max
#> perturbation curve perturbation curve 5       -20        20 0.1819731 0.4093701
#>                    crossing direction
#> perturbation curve       NA      <NA>
```
