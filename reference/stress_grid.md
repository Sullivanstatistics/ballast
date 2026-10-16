# Perturbation family: crossed specification grid

Fits every combination of the supplied covariance structures, inference
settings, covariate sets and data sets (a specification curve). The cell
that reproduces the spec is flagged `is_base`.

## Usage

``` r
stress_grid(
  spec,
  covariance = spec$covariance,
  inference = list(base = list(method = spec$method, vcov = spec$vcov)),
  covariates = list(base = spec$covariates),
  data = list(base = NULL),
  cores = 1L
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- covariance:

  Character vector of covariance structures.

- inference:

  Named list of `list(method = , vcov = )` pairs.

- covariates:

  Named list of covariate sets (formulas or term labels).

- data:

  Named list of data frames; a `NULL` element is the spec's data.

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame, one row per cell, labelled
`"covariance | inference | covariates | data"`.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
stress_grid(spec, covariance = c("us", "cs"),
            covariates = list(full = ~ RACE + SEX + FEV1_BL, baseline = ~ FEV1_BL))
#>               family                       label        kind        role
#> 1 specification grid     us | base | full | base alternative sensitivity
#> 2 specification grid     cs | base | full | base alternative sensitivity
#> 3 specification grid us | base | baseline | base alternative sensitivity
#> 4 specification grid cs | base | baseline | base alternative sensitivity
#>   is_base converged note estimate   stderr       df      lcl      ucl
#> 1    TRUE      TRUE      4.404001 1.673014 132.8789 1.094816 7.713186
#> 2   FALSE      TRUE      4.228701 1.120836 520.7284 2.026785 6.430617
#> 3   FALSE      TRUE      5.012058 1.719443 134.3691 1.611385 8.412731
#> 4   FALSE      TRUE      4.936975 1.169538 518.9253 2.639364 7.234585
#>              p n_subj n_obs     aicc param covariance        method
#> 1 9.483085e-03    197   537 3381.807    NA         us Kenward-Roger
#> 2 1.799571e-04    197   537 3506.404    NA         cs Kenward-Roger
#> 3 4.169348e-03    197   537 3450.508    NA         us Kenward-Roger
#> 4 2.867844e-05    197   537 3556.503    NA         cs Kenward-Roger
#>                   vcov           covariates alpha
#> 1 Kenward-Roger-Linear RACE + SEX + FEV1_BL  0.05
#> 2 Kenward-Roger-Linear RACE + SEX + FEV1_BL  0.05
#> 3 Kenward-Roger-Linear              FEV1_BL  0.05
#> 4 Kenward-Roger-Linear              FEV1_BL  0.05
```
