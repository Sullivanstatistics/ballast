# Explain why an alternative analysis moved

For one row of a census (an alternative that crossed alpha, say),
attributes the difference between its estimate and the pre-specified
estimate to subjects. Each subject's influence is the change in the
contrast when that subject is removed, computed under the pre-specified
settings and again under the alternative's settings; the difference of
the two influences says how much more (or less) that subject drives the
result under the alternative. Subjects are ranked by the absolute
difference.

## Usage

``` r
stress_explain(spec, row, data = NULL, top = 10, cores = 1L)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- row:

  One row of a `stress_census` or `stress_rows` data frame.

- data:

  The alternative's data set, if it differs from the spec's.

- top:

  Number of subjects to print.

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A data frame of class `stress_explanation` with one row per subject:
`subject`, `arm`, `n_visits`, `infl_base`, `infl_alt`, `difference`,
sorted by absolute difference; the row explained is `attr(, "row")` and
the two full-data estimates are `attr(, "estimates")`.

## Details

The alternative's model settings are read from the row (`covariance`,
`method`, `vcov`, `covariates`). For an alternative that used different
data, pass that data as `data`.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:30), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
cen <- stress_census(spec, stress_covariates(spec))
stress_explain(spec, cen[1, ], top = 5)
#> Alternative: covariate set / without FEV1_BL
#> Estimate 5.735 (pre-specified) -> 7.913 (alternative); shift 2.18
#> Subjects whose influence changes most (influence = estimate minus estimate without the subject):
#>  subject arm n_visits infl_base infl_alt difference
#>     PT15 PBO        2   0.00533    0.690      0.684
#>     PT17 PBO        2  -0.18286    0.467      0.650
#>     PT16 PBO        2   0.05930   -0.370     -0.429
#>      PT2 PBO        3  -0.25015   -0.678     -0.427
#>      PT3 PBO        2   1.52624    1.113     -0.413
```
