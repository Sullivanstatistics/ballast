# Perturbation family: leave-one-out deletions

Refits the model with each subject removed, or with each level of a
grouping variable (site, cohort, country) removed. Rows are
`kind = "deletion"` and are summarised separately from alternative
analyses.

## Usage

``` r
stress_loo(spec, by = NULL, cores = 1L)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- by:

  Name of a grouping column; `NULL` deletes subjects one at a time.

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame, one row per deleted unit.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:40), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL)
stress_loo(spec, by = "RACE")
#>                family                     label     kind        role is_base
#> 1 leave-one-out: RACE                     Asian deletion sensitivity   FALSE
#> 2 leave-one-out: RACE Black or African American deletion sensitivity   FALSE
#> 3 leave-one-out: RACE                     White deletion sensitivity   FALSE
#>   converged                note estimate   stderr       df        lcl      ucl
#> 1      TRUE 15 subjects removed 4.200848 5.999589 16.38230 -8.4936339 16.89533
#> 2      TRUE 15 subjects removed 6.697562 3.681770 21.52430 -0.9477579 14.34288
#> 3      TRUE 10 subjects removed 1.633473 4.383239 20.12223 -7.5062444 10.77319
#>            p n_subj n_obs     aicc param covariance        method
#> 1 0.49363371     25    70 439.9187    NA         us Kenward-Roger
#> 2 0.08283463     25    76 482.1284    NA         us Kenward-Roger
#> 3 0.71329536     30    82 509.8967    NA         us Kenward-Roger
#>                   vcov covariates alpha
#> 1 Kenward-Roger-Linear    FEV1_BL  0.05
#> 2 Kenward-Roger-Linear    FEV1_BL  0.05
#> 3 Kenward-Roger-Linear    FEV1_BL  0.05
```
