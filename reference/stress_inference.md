# Perturbation family: degrees-of-freedom method and variance estimator

Perturbation family: degrees-of-freedom method and variance estimator

## Usage

``` r
stress_inference(spec, settings = default_inference(), cores = 1L)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- settings:

  Named list of `list(method = , vcov = )` pairs; see
  [`default_inference()`](https://sullivanstatistics.github.io/ballast/reference/default_inference.md).

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame, one row per setting.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
stress_inference(spec, default_inference()[c("Satterthwaite", "Kenward-Roger (linear)")])
#>      family                  label        kind        role is_base converged
#> 1 inference          Satterthwaite alternative sensitivity   FALSE      TRUE
#> 2 inference Kenward-Roger (linear) alternative sensitivity    TRUE      TRUE
#>   note estimate   stderr       df      lcl      ucl           p n_subj n_obs
#> 1      4.404001 1.660487 132.8789 1.119595 7.688407 0.008969722    197   537
#> 2      4.404001 1.673014 132.8789 1.094816 7.713186 0.009483085    197   537
#>       aicc param covariance        method                 vcov
#> 1 3381.807    NA         us Satterthwaite           Asymptotic
#> 2 3381.807    NA         us Kenward-Roger Kenward-Roger-Linear
#>             covariates alpha
#> 1 RACE + SEX + FEV1_BL  0.05
#> 2 RACE + SEX + FEV1_BL  0.05
```
