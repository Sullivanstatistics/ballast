# Candidate analytic changes for the path search

Lists the analytic changes
[`stress_path()`](https://sullivanstatistics.github.io/ballast/reference/stress_path.md)
may combine. Each change belongs to a family (covariance structure,
inference, covariate set, LS-mean weighting, reference-based imputation,
analysis data set), and a path changes each family at most once.
Participant and site deletions are not analytic changes; they are
measured separately by
[`stress_fragility()`](https://sullivanstatistics.github.io/ballast/reference/stress_fragility.md).

## Usage

``` r
path_changes(
  spec,
  covariance = c("us", "ar1h", "cs"),
  inference = default_inference()[c("Satterthwaite", "Kenward-Roger (linear)",
    "Sandwich, between-within")],
  covariates = TRUE,
  weights = TRUE,
  reference = c("J2R", "CR", "CIR"),
  delta_adjusted = numeric(),
  m = 10,
  data = list()
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- covariance:

  Alternative covariance structures.

- inference:

  Named list of `list(method = , vcov = )` alternatives.

- covariates:

  `TRUE` to drop each covariate and (with two or more) all of them; a
  named list of covariate sets to use instead; `FALSE` for none.

- weights:

  `TRUE` to include the other LS-mean weighting.

- reference:

  Reference-based imputation assumptions (any of `"MAR"`, `"J2R"`,
  `"CR"`, `"CIR"`);
  [`character()`](https://rdrr.io/r/base/character.html) for none.

- delta_adjusted:

  Shifts for delta-adjusted imputation under MAR. Each value is one
  change that adds the shift to every imputed value of the active arm
  (for example minus half the residual SD, against the active arm). It
  belongs to the reference-based imputation family, so a path uses at
  most one missing-data assumption.
  [`numeric()`](https://rdrr.io/r/base/numeric.html) for none.

- m:

  Imputations per reference-based analysis.

- data:

  Named list of alternative analysis data sets (for example, other
  intercurrent-event handlings).

## Value

A list of changes, each a list with `family`, `label`, `type` (`"spec"`
or `"mi"`) and `value`.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + FEV1_BL)
vapply(path_changes(spec, reference = character()), `[[`, "", "label")
#> [1] "ar1h"                     "cs"                      
#> [3] "Satterthwaite"            "Sandwich, between-within"
#> [5] "without RACE"             "without FEV1_BL"         
#> [7] "no covariates"            "observed LS-mean weights"
```
