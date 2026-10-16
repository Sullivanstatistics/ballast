# Perturbation family: within-subject covariance structure

Refits the pre-specified model under each covariance structure. The row
that reproduces the spec's own structure is flagged `is_base`.

## Usage

``` r
stress_covariance(
  spec,
  structures = c("us", "ar1h", "ar1", "cs", "csh", "toep", "toeph"),
  cores = 1L
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- structures:

  Covariance structure names (see
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md)).

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame, one row per structure.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
stress_covariance(spec, c("us", "cs", "ar1h"))
#>                 family label        kind        role is_base converged note
#> 1 covariance structure    us alternative sensitivity    TRUE      TRUE     
#> 2 covariance structure    cs alternative sensitivity   FALSE      TRUE     
#> 3 covariance structure  ar1h alternative sensitivity   FALSE      TRUE     
#>   estimate   stderr       df       lcl      ucl            p n_subj n_obs
#> 1 4.404001 1.673014 132.8789 1.0948163 7.713186 0.0094830850    197   537
#> 2 4.228701 1.120836 520.7284 2.0267855 6.430617 0.0001799571    197   537
#> 3 4.188476 1.672810 131.5430 0.8793865 7.497565 0.0135079357    197   537
#>       aicc param covariance        method                 vcov
#> 1 3381.807    NA         us Kenward-Roger Kenward-Roger-Linear
#> 2 3506.404    NA         cs Kenward-Roger Kenward-Roger-Linear
#> 3 3385.911    NA       ar1h Kenward-Roger Kenward-Roger-Linear
#>             covariates alpha
#> 1 RACE + SEX + FEV1_BL  0.05
#> 2 RACE + SEX + FEV1_BL  0.05
#> 3 RACE + SEX + FEV1_BL  0.05
```
