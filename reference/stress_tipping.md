# Perturbation family: delta-adjusted multiple imputation (tipping point)

Imputes the missing responses by fully conditional specification
(regression method, one column per visit, subject-level covariates and
treatment as predictors), adds `delta` to every imputed value of the
active arm, refits the pre-specified model on each completed data set
and pools with Rubin's rules. `delta = 0` is the missing-at-random
multiple-imputation analysis and is a counted alternative; other deltas
are tipping-point searches (`kind = "search"`). Rows carry the delta in
`param`.

## Usage

``` r
stress_tipping(
  spec,
  deltas = seq(0, -10, by = -2),
  m = 25,
  seed = 1,
  arm = NULL,
  shift_visits = NULL,
  impute_covariates = NULL,
  nbiter = 10,
  shift_every = TRUE,
  cores = 1L
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- deltas:

  Shifts added to the imputed values of the active arm, in response
  units.

- m:

  Number of imputations.

- seed:

  Random seed (the same seed is used for every delta).

- arm:

  Treatment level receiving the shift; defaults to the active arm.

- shift_visits:

  Visit levels whose imputed values are shifted; `NULL` shifts every
  visit.

- impute_covariates:

  Subject-level covariates used as predictors in the imputation model
  (with treatment and the visit columns); `NULL` uses every spec
  covariate that is constant within subject. Covariates that vary within
  subject cannot be used.

- nbiter:

  Burn-in iterations of the FCS sampler.

- shift_every:

  If `TRUE` the shift is applied at every draw (SAS `MNAR ADJUST` under
  FCS); if `FALSE` only to the final imputation.

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame, one row per delta; `note` records the number
of imputations and the Monte Carlo standard error of the pooled
estimate.

## Details

Covariates that vary within subject are excluded from the imputation
model and are kept in the analysis model; subject-visit rows absent from
the data are created for the imputed response with those covariates
missing, so they drop out of the refit.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:80), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL)
stress_tipping(spec, deltas = c(0, -5), m = 3)
#>                               family    label        kind        role is_base
#> 1 delta-adjusted multiple imputation  delta 0 alternative sensitivity   FALSE
#> 2 delta-adjusted multiple imputation delta -5      search sensitivity   FALSE
#>   converged
#> 1      TRUE
#> 2      TRUE
#>                                                                                note
#> 1 shift on TRT at all visits; seed 1; m = 3 of 3 converged; MC SE of estimate 0.681
#> 2 shift on TRT at all visits; seed 1; m = 3 of 3 converged; MC SE of estimate 0.603
#>   estimate   stderr       df       lcl      ucl         p n_subj n_obs aicc
#> 1 3.885759 2.670879 29.54786 -1.572405 9.343924 0.1562495     80   320   NA
#> 2 2.532657 2.658249 47.06471 -2.814856 7.880170 0.3455825     80   320   NA
#>   param covariance        method                 vcov covariates alpha
#> 1     0         us Kenward-Roger Kenward-Roger-Linear    FEV1_BL  0.05
#> 2    -5         us Kenward-Roger Kenward-Roger-Linear    FEV1_BL  0.05
```
