# Perturbation family: covariate set

Refits the model with each covariate dropped in turn, with no
covariates, and with any user-supplied covariate sets.

## Usage

``` r
stress_covariates(
  spec,
  drop_each = TRUE,
  drop_all = TRUE,
  sets = list(),
  cores = 1L
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- drop_each:

  Drop each pre-specified covariate term in turn.

- drop_all:

  Fit with treatment and visit only.

- sets:

  Named list of additional covariate sets (formulas or character vectors
  of term labels); each is fitted as given.

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
stress_covariates(spec, sets = list("with weight" = ~ RACE + SEX + FEV1_BL + WEIGHT))
#>          family           label        kind        role is_base converged note
#> 1 covariate set    without RACE alternative sensitivity   FALSE      TRUE     
#> 2 covariate set     without SEX alternative sensitivity   FALSE      TRUE     
#> 3 covariate set without FEV1_BL alternative sensitivity   FALSE      TRUE     
#> 4 covariate set   no covariates alternative sensitivity   FALSE      TRUE     
#> 5 covariate set     with weight alternative sensitivity   FALSE      TRUE     
#>   estimate   stderr       df      lcl      ucl           p n_subj n_obs
#> 1 5.012791 1.720141 134.3774 1.610739 8.414844 0.004178821    197   537
#> 2 4.414595 1.673451 132.8415 1.104538 7.724653 0.009334864    197   537
#> 3 4.398457 1.693408 133.3887 1.049051 7.747863 0.010447854    197   537
#> 4 4.968179 1.740325 134.9465 1.526339 8.410019 0.004987873    197   537
#> 5 4.330783 1.673814 133.0583 1.020058 7.641508 0.010744181    197   537
#>       aicc param covariance        method                 vcov
#> 1 3449.733    NA         us Kenward-Roger Kenward-Roger-Linear
#> 2 3382.668    NA         us Kenward-Roger Kenward-Roger-Linear
#> 3 3406.877    NA         us Kenward-Roger Kenward-Roger-Linear
#> 4 3470.833    NA         us Kenward-Roger Kenward-Roger-Linear
#> 5 3378.852    NA         us Kenward-Roger Kenward-Roger-Linear
#>                      covariates alpha
#> 1                 SEX + FEV1_BL  0.05
#> 2                RACE + FEV1_BL  0.05
#> 3                    RACE + SEX  0.05
#> 4                                0.05
#> 5 RACE + SEX + FEV1_BL + WEIGHT  0.05
```
