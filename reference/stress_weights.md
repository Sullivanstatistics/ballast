# Perturbation family: least-squares-mean weighting

Refits the pre-specified model and forms the treatment contrast with the
other weighting of the class covariates: equal weights over levels (SAS
`LSMEANS` default) versus the observed covariate distribution of the
analysis rows (SAS `OBSMARGINS`, g-computation). The point estimate
differs only when a class covariate interacts with treatment or visit;
the two rows otherwise coincide.

## Usage

``` r
stress_weights(spec, cores = 1L)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame with two rows, one flagged `is_base`.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
stress_weights(spec)
#>              family                    label        kind        role is_base
#> 1 LS-mean weighting    equal LS-mean weights alternative sensitivity    TRUE
#> 2 LS-mean weighting observed LS-mean weights alternative sensitivity   FALSE
#>   converged note estimate   stderr       df      lcl      ucl           p
#> 1      TRUE      4.404001 1.673014 132.8789 1.094816 7.713186 0.009483085
#> 2      TRUE      4.404001 1.673014 132.8789 1.094816 7.713186 0.009483085
#>   n_subj n_obs     aicc param covariance        method                 vcov
#> 1    197   537 3381.807    NA         us Kenward-Roger Kenward-Roger-Linear
#> 2    197   537 3381.807    NA         us Kenward-Roger Kenward-Roger-Linear
#>             covariates alpha
#> 1 RACE + SEX + FEV1_BL  0.05
#> 2 RACE + SEX + FEV1_BL  0.05
```
