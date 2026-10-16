# Assemble a census of perturbations against the base analysis

Binds the rows returned by the family functions and scores each against
the pre-specified (base) fit: percent of the base estimate, shift in
base standard errors, whether the estimate lies inside the base
confidence interval, keeps the base direction, is significant at
`alpha`, and whether significance changed. Rows that reproduce the base
(`is_base`), did not converge, are tipping-point searches, or duplicate
an earlier row are not counted.

## Usage

``` r
stress_census(spec, ..., base = NULL)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md);
  the base fit is `stress_fit(spec)`.

- ...:

  `stress_rows` data frames from the family functions.

- base:

  Optional pre-computed base row, to avoid refitting.

## Value

A data frame of class `stress_census` with the family rows plus
`pct_of_base`, `shift_se`, `inside_ci`, `same_direction`, `significant`,
`crossed`, `duplicate` (a later row numerically identical to an earlier
counted row, so the same specification reached by two families),
`counted`; the base row is `attr(, "base")`.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
cen <- stress_census(spec, stress_covariance(spec, c("us", "cs", "ar1h")),
                     stress_covariates(spec))
summary(cen)
#> Base analysis: estimate 4.4 (SE 1.67), 95% CI 1.09 to 7.71, p = 0.00948
#>                family        kind n significant crossed outside_ci reversed
#>  covariance structure alternative 2           2       0          0        0
#>         covariate set alternative 4           4       0          0        0
#>       All sensitivity         all 6           6       0          0        0
#>                   All         all 6           6       0          0        0
#>  pct_min pct_max max_shift_se        role
#>       95      96         0.13 sensitivity
#>      100     114         0.36 sensitivity
#>       95     114         0.36 sensitivity
#>       95     114         0.36         all
stress_verdict(cen)
#> Base: estimate 4.4, 95% CI 1.09 to 7.71, p = 0.00948 (alpha 0.05)
#> Counted: 6 alternative analyses, 0 deletions; 6 significant, 0 crossed alpha
#> Outside base CI: 0; direction reversed: 0; largest shift: 0.364 base SE
#> Verdict: ROBUST over all counted rows; ROBUST over the 6 sensitivity analyses (same estimand; 0 supplementary rows)
```
