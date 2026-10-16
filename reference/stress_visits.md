# Perturbation family: the contrast at every visit

Fits the pre-specified model once per visit and reports the treatment
contrast at each; the contrast at the pre-specified visit is flagged
`is_base`. A different visit is a different estimand, so the rows are
`role = "supplementary"`.

## Usage

``` r
stress_visits(spec, visits = NULL, cores = 1L)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- visits:

  Visit levels; `NULL` for all.

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame, one row per visit.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
stress_visits(spec)
#>           family            label        kind          role is_base converged
#> 1 contrast visit contrast at VIS1 alternative supplementary   FALSE      TRUE
#> 2 contrast visit contrast at VIS2 alternative supplementary   FALSE      TRUE
#> 3 contrast visit contrast at VIS3 alternative supplementary   FALSE      TRUE
#> 4 contrast visit contrast at VIS4 alternative supplementary    TRUE      TRUE
#>   note estimate    stderr       df      lcl      ucl            p n_subj n_obs
#> 1      3.983290 1.0531342 142.3210 1.901483 6.065097 2.280818e-04    197   537
#> 2      3.930758 0.8178763 142.2576 2.313997 5.547520 3.866542e-06    197   537
#> 3      2.983718 0.6712952 129.6093 1.655603 4.311833 1.869959e-05    197   537
#> 4      4.404001 1.6730142 132.8789 1.094816 7.713186 9.483085e-03    197   537
#>       aicc param covariance        method                 vcov
#> 1 3381.807    NA         us Kenward-Roger Kenward-Roger-Linear
#> 2 3381.807    NA         us Kenward-Roger Kenward-Roger-Linear
#> 3 3381.807    NA         us Kenward-Roger Kenward-Roger-Linear
#> 4 3381.807    NA         us Kenward-Roger Kenward-Roger-Linear
#>             covariates alpha
#> 1 RACE + SEX + FEV1_BL  0.05
#> 2 RACE + SEX + FEV1_BL  0.05
#> 3 RACE + SEX + FEV1_BL  0.05
#> 4 RACE + SEX + FEV1_BL  0.05
```
