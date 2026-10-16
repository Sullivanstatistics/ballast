# Perturbation family: analysis population

Each rule is a function of the spec's data returning a logical vector of
rows to keep (a per-protocol flag, a completer definition, a cohort).

## Usage

``` r
stress_population(spec, rules, role = "supplementary", cores = 1L)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- rules:

  Named list of functions `function(data) logical`.

- role:

  `"supplementary"` (the default: a different population is a different
  estimand) or `"sensitivity"`.

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame, one row per rule.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
stress_population(spec, list("female" = function(d) d$SEX == "Female"))
#>                family  label        kind          role is_base converged
#> 1 analysis population female alternative supplementary   FALSE      TRUE
#>                               note estimate   stderr       df       lcl
#> 1 [SEX single-level, term dropped] 3.644427 2.373197 68.47812 -1.090616
#>        ucl         p n_subj n_obs    aicc param covariance        method
#> 1 8.379471 0.1292293    105   288 1806.34    NA         us Kenward-Roger
#>                   vcov     covariates alpha
#> 1 Kenward-Roger-Linear RACE + FEV1_BL  0.05
```
