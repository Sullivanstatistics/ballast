# Run a pre-specified stress test

Runs every family in a
[`stress_plan()`](https://sullivanstatistics.github.io/ballast/reference/stress_plan.md),
assembles the census and the verdict, and keeps the rows by family.

## Usage

``` r
run_plan(plan, cores = 1L, seed = 1)
```

## Arguments

- plan:

  A `stress_plan`.

- cores:

  Worker processes passed to every family.

- seed:

  Seed passed to the families that take one, unless the plan sets it.

## Value

An object of class `stress_result`: `plan`, `rows` (a list of
`stress_rows` by family), `census`, `verdict`, `base` and `elapsed`.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
plan <- stress_plan(spec, covariance = list(structures = c("cs", "ar1h")),
                    inference = NULL, covariates = NULL, weights = FALSE,
                    loo = list(by = "RACE"), permute = list(n = 9), reference = NULL,
                    estimator = list(estimators = "ancova"), fragility = list(max_k = 1))
res <- run_plan(plan)
res
#> Pre-specified stress test
#> 5 families, 8 rows, 7 counted; 0.0 min
#> Base: estimate 3.48, 95% CI -0.796 to 7.75, p = 0.11 (alpha 0.05)
#> Counted: 3 alternative analyses, 4 deletions; 1 significant, 1 crossed alpha
#> Outside base CI: 0; direction reversed: 0; largest shift: 0.556 base SE
#> Verdict: SENSITIVE over all counted rows; SENSITIVE over the 7 sensitivity analyses (same estimand; 0 supplementary rows)
#> Rows that crossed alpha:
#>                  family label estimate      p
#>  greedy deletion search   PT1     4.68 0.0251
```
