# Perturbation family: reference-based multiple imputation

Imputes the missing responses from a multivariate-normal imputation
model (an MMRM on the observed data with treatment by visit, the
subject-level covariates and an unstructured covariance) under the
standard reference-based assumptions (Carpenter, Roger and Kenward,
2013), refits the pre-specified model on each completed data set and
pools with Rubin's rules:

## Usage

``` r
stress_reference(
  spec,
  methods = c("MAR", "J2R", "CR", "CIR"),
  m = 25,
  seed = 1,
  delta = 0,
  arm = NULL,
  impute_covariates = NULL,
  same_cov = TRUE,
  max_tries = 3L,
  cores = 1L
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- methods:

  Assumptions to run, from `"MAR"`, `"J2R"`, `"CR"`, `"CIR"`.

- m:

  Number of imputations.

- seed:

  Random seed (the same seed is used for every delta).

- delta:

  Shift added to the active arm's imputed values (response units); `0`
  for none.

- arm:

  Treatment level receiving the shift; defaults to the active arm.

- impute_covariates:

  Subject-level covariates used as predictors in the imputation model
  (with treatment and the visit columns); `NULL` uses every spec
  covariate that is constant within subject. Covariates that vary within
  subject cannot be used.

- same_cov:

  If `TRUE` one covariance matrix is shared by both arms in the
  imputation model; if `FALSE` each arm has its own, and the reference
  arm's is used for the reference-based draws.

- max_tries:

  Bootstrap refits attempted per imputation before giving up.

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame, one counted row per method
(`role = "sensitivity"`), with the number of imputations and the Monte
Carlo standard error in `note`.

## Details

- `MAR`: every subject's missing values follow their own arm.

- `J2R` (jump to reference): an active-arm subject's visits after the
  last observed one take the reference arm's means.

- `CR` (copy reference): an active-arm subject with any missing value
  follows the reference arm's means at every visit.

- `CIR` (copy increments in reference): after the last observed visit
  the subject keeps their own-arm mean at that visit and then changes as
  the reference arm does.

Visits missing before the last observed one are treated as missing at
random under every assumption. Parameter uncertainty is carried by
approximate Bayesian draws: for each imputation the imputation model is
refitted on a bootstrap sample of subjects (stratified by arm) and its
fixed effects and covariance are used to draw the missing values from
the conditional normal distribution given the subject's observed values.
An optional `delta` is added to every imputed value of the active arm.

Imputation `i` uses seed `seed + i` on whichever worker draws it, so the
result is the same for any number of `cores`.

## References

Carpenter JR, Roger JH, Kenward MG (2013). Analysis of longitudinal
trials with protocol deviation: a framework for relevant, accessible
assumptions, and inference via multiple imputation. Journal of
Biopharmaceutical Statistics 23, 1352-1371.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:100), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
stress_reference(spec, methods = c("MAR", "J2R"), m = 3)
#>                                family label        kind        role is_base
#> 1 reference-based multiple imputation   MAR alternative sensitivity   FALSE
#> 2 reference-based multiple imputation   J2R alternative sensitivity   FALSE
#>   converged
#> 1      TRUE
#> 2      TRUE
#>                                                                                                      note
#> 1 reference PBO, shift 0 on TRT, common covariance, seed 1; m = 3 of 3 converged; MC SE of estimate 0.669
#> 2 reference PBO, shift 0 on TRT, common covariance, seed 1; m = 3 of 3 converged; MC SE of estimate 0.523
#>   estimate   stderr        df       lcl      ucl          p n_subj n_obs aicc
#> 1 4.793579 1.907971  8.257192 0.4175297 9.169627 0.03537227    100   400   NA
#> 2 3.757438 1.700744 13.967595 0.1089108 7.405965 0.04436303    100   400   NA
#>   param covariance        method       vcov covariates alpha
#> 1    NA         cs Satterthwaite Asymptotic    FEV1_BL  0.05
#> 2    NA         cs Satterthwaite Asymptotic    FEV1_BL  0.05
```
