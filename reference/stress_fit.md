# Fit one MMRM and return one row

Fits the model described by a
[`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md)
(optionally on alternative data or with alternative settings) and
returns the treatment contrast at the contrast visit as a single row in
the package's common schema. This is the engine every family function
calls.

## Usage

``` r
stress_fit(
  spec,
  data = NULL,
  label = spec$label,
  family = "base",
  kind = "alternative",
  is_base = is.null(data),
  note = "",
  covariates = spec$covariates,
  covariance = spec$covariance,
  method = spec$method,
  vcov = spec$vcov,
  at = list(),
  role = "sensitivity",
  weights = spec$weights
)
```

## Arguments

- spec:

  A `stress_spec`.

- data:

  Alternative data set in the same layout as `spec$data`; `NULL` fits
  the spec's own data.

- label, family, kind:

  Labels for the output row. `kind` is one of `"alternative"` (a counted
  alternative analysis), `"deletion"` (a leave-one-out refit) or
  `"search"` (a point on a tipping-point grid).

- is_base:

  `TRUE` when the row reproduces the pre-specified analysis exactly;
  such rows are not counted in a census.

- note:

  Free text carried into the row.

- covariates, covariance, method, vcov:

  Overrides of the spec's settings.

- at:

  Named list of continuous covariates fixed at a value instead of their
  mean when forming the least-squares means (SAS `LSMEANS ... AT`).

- role:

  `"sensitivity"` for an analysis that keeps the estimand and changes an
  assumption or a modelling choice; `"supplementary"` for one that
  targets a different estimand (ICH E9(R1)).

- weights:

  LS-mean weighting, `"equal"` or `"observed"`; see
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

## Value

A one-row data frame of class `stress_rows` with columns `family`,
`label`, `kind`, `role`, `is_base`, `converged`, `note`, `estimate`,
`stderr`, `df`, `lcl`, `ucl`, `p`, `n_subj`, `n_obs`, `aicc`, `param`
(the numeric value of a continuous perturbation, `NA` otherwise),
`covariance`, `method`, `vcov`, `covariates`, `alpha`.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
stress_fit(spec)
#>   family         label        kind        role is_base converged note estimate
#> 1   base pre-specified alternative sensitivity    TRUE      TRUE      4.404001
#>     stderr       df      lcl      ucl           p n_subj n_obs     aicc param
#> 1 1.673014 132.8789 1.094816 7.713186 0.009483085    197   537 3381.807    NA
#>   covariance        method                 vcov           covariates alpha
#> 1         us Kenward-Roger Kenward-Roger-Linear RACE + SEX + FEV1_BL  0.05
```
