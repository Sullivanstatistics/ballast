# Perturbation family: estimator class

Refits the question with estimators other than the pre-specified MMRM:

## Usage

``` r
stress_estimator(
  spec,
  estimators = c("complete_cases", "gee_independence", "ancova", "robust_ancova",
    "random_intercept", "clda"),
  random = NULL,
  baseline = NULL,
  seed = 1,
  cores = 1L,
  diagnostic = NULL
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- estimators:

  Which estimators to run.

- random:

  Name of a grouping column for `"random_intercept"` (a site or centre
  variable that is also one of the spec's covariates).

- baseline:

  Name of the baseline column for `"clda"`; the response must be change
  from that baseline.

- seed:

  Seed for the robust regression's random initial estimate.

- cores:

  Number of worker processes; `1` fits sequentially.

- diagnostic:

  Names of estimators (from `estimators`) whose rows are diagnostic:
  fitted, drawn and tabulated with `kind = "diagnostic"`, but not
  counted by
  [`stress_census()`](https://sullivanstatistics.github.io/ballast/reference/stress_census.md),
  so they do not enter the verdict or its counts. `NULL` (the default)
  counts every estimator. The standard plan
  ([`standard_plan()`](https://sullivanstatistics.github.io/ballast/reference/standard_plan.md))
  makes the complete-case refit diagnostic.

## Value

A `stress_rows` data frame, one row per estimator.

## Details

- `"complete_cases"`: the pre-specified MMRM on subjects observed at
  every visit (no reliance on missing-at-random within the likelihood).

- `"gee_independence"`: working-independence weighted least squares with
  a visit-specific residual variance and a cluster-robust (sandwich)
  variance, between-within degrees of freedom; no within-subject
  covariance is modelled. Needs `nlme`.

- `"ancova"`: analysis of covariance at the contrast visit, observed
  cases, residual degrees of freedom. Covariate terms involving the
  visit variable are dropped.

- `"robust_ancova"`: MM-type robust regression at the contrast visit
  ([`MASS::rlm`](https://rdrr.io/pkg/MASS/man/rlm.html)), normal-theory
  inference. Needs `MASS`.

- `"clda"`: constrained longitudinal data analysis: the raw outcome
  (`baseline` plus the response, which must be a change from baseline)
  is modelled at baseline and every post-baseline visit with one common
  baseline mean across arms, an unstructured covariance over all visits
  and the other covariates as fixed effects; the contrast is the
  difference in the arms' means at the contrast visit. Needs `baseline`.

- `"random_intercept"`: the pre-specified fixed effects with `random` as
  a random intercept instead of a fixed covariate, the spec's covariance
  structure within subject where `nlme` has an equivalent (`us`, `ar1h`,
  `ar1`, `cs`, `csh`); normal-theory inference. Needs `nlme` and
  `random`.

Every estimator reports the same least-squares-mean contrast at the
contrast visit (class covariates at equal weights, continuous covariates
at their means).

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
stress_estimator(spec, c("complete_cases", "ancova"))
#>            family                        label        kind        role is_base
#> 1 estimator class       MMRM on complete cases alternative sensitivity   FALSE
#> 2 estimator class ANCOVA at the contrast visit alternative sensitivity   FALSE
#>   converged                                        note estimate   stderr
#> 1      TRUE 39 of 197 subjects observed at all 4 visits  9.42062 3.885616
#> 2      TRUE                 observed cases, residual df  3.89943 1.686347
#>          df      lcl       ucl          p n_subj n_obs     aicc param
#> 1  36.97146 1.547409 17.293831 0.02033658     39   156 983.7926    NA
#> 2 128.00000 0.562705  7.236155 0.02235472    134   134       NA    NA
#>   covariance        method                 vcov           covariates alpha
#> 1         us Kenward-Roger Kenward-Roger-Linear RACE + SEX + FEV1_BL  0.05
#> 2         us      Residual             see note RACE + SEX + FEV1_BL  0.05
```
