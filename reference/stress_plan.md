# Pre-specify a stress test

A plan names the families to run and their settings before unblinding,
so the stress test can be written into a statistical analysis plan and
run with one call
([`run_plan()`](https://sullivanstatistics.github.io/ballast/reference/run_plan.md)).
Each family argument is `NULL` to skip the family, an empty
[`list()`](https://rdrr.io/r/base/list.html) to run it with its
defaults, or a named list of arguments for the family function. Printing
the plan gives the text a statistical analysis plan can carry.

## Usage

``` r
stress_plan(
  spec,
  covariance = list(),
  inference = list(),
  covariates = list(),
  weights = TRUE,
  population = NULL,
  data = NULL,
  loo = list(),
  grid = NULL,
  permute = list(n = 2000),
  tipping = NULL,
  reference = list(),
  estimator = list(),
  fragility = list(),
  curve = NULL,
  estimand = NULL,
  visits = NULL,
  title = "Pre-specified stress test",
  rule = c("interval", "interval_or_direction")
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md):
  the pre-specified analysis.

- covariance:

  Arguments for
  [`stress_covariance()`](https://sullivanstatistics.github.io/ballast/reference/stress_covariance.md).

- inference:

  Arguments for
  [`stress_inference()`](https://sullivanstatistics.github.io/ballast/reference/stress_inference.md).

- covariates:

  Arguments for
  [`stress_covariates()`](https://sullivanstatistics.github.io/ballast/reference/stress_covariates.md).

- weights:

  `TRUE` to run
  [`stress_weights()`](https://sullivanstatistics.github.io/ballast/reference/stress_weights.md).

- population:

  Arguments for
  [`stress_population()`](https://sullivanstatistics.github.io/ballast/reference/stress_population.md)
  (needs `rules`).

- data:

  Arguments for
  [`stress_data()`](https://sullivanstatistics.github.io/ballast/reference/stress_data.md)
  (needs `alternatives`).

- loo:

  Arguments for
  [`stress_loo()`](https://sullivanstatistics.github.io/ballast/reference/stress_loo.md);
  a list of lists runs it several times (subjects and a site variable,
  say).

- grid:

  Arguments for
  [`stress_grid()`](https://sullivanstatistics.github.io/ballast/reference/stress_grid.md).

- permute:

  Arguments for
  [`stress_permute()`](https://sullivanstatistics.github.io/ballast/reference/stress_permute.md).

- tipping:

  Arguments for
  [`stress_tipping()`](https://sullivanstatistics.github.io/ballast/reference/stress_tipping.md)
  (needs `deltas`).

- reference:

  Arguments for
  [`stress_reference()`](https://sullivanstatistics.github.io/ballast/reference/stress_reference.md).

- estimator:

  Arguments for
  [`stress_estimator()`](https://sullivanstatistics.github.io/ballast/reference/stress_estimator.md).

- fragility:

  Arguments for
  [`stress_fragility()`](https://sullivanstatistics.github.io/ballast/reference/stress_fragility.md).

- curve:

  Arguments for
  [`stress_curve()`](https://sullivanstatistics.github.io/ballast/reference/stress_curve.md)
  (needs `values` and `modify`).

- estimand:

  Arguments for
  [`stress_estimand()`](https://sullivanstatistics.github.io/ballast/reference/stress_estimand.md)
  (needs `ice`).

- visits:

  Arguments for
  [`stress_visits()`](https://sullivanstatistics.github.io/ballast/reference/stress_visits.md).

- title:

  A title for the plan.

- rule:

  Classification rule passed to
  [`stress_verdict()`](https://sullivanstatistics.github.io/ballast/reference/stress_verdict.md):
  `"interval"` (default) or `"interval_or_direction"`.

## Value

An object of class `stress_plan`.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
plan <- stress_plan(spec, covariance = list(structures = c("us", "cs", "ar1h")),
                    inference = list(), covariates = list(), loo = list(by = "RACE"),
                    permute = NULL, reference = NULL, estimator = list(estimators = "ancova"),
                    fragility = list(max_k = 2))
plan
#> Pre-specified stress test
#> 
#> Pre-specified analysis: FEV1 ~ RACE + SEX + FEV1_BL + ARMCD + AVISIT + ARMCD:AVISIT + us(AVISIT | USUBJID); contrast TRT minus PBO at VIS4; Kenward-Roger df, Kenward-Roger-Linear variance; alpha 0.05; equal LS-mean weights.
#> 
#> Perturbation families, run after unblinding exactly as listed; every refit is judged against the pre-specified estimate,
#> its 95% confidence interval and alpha.
#> Classification: fragile if any counted refit (an alternative analysis or a deletion) lands outside the pre-specified 95% confidence interval; otherwise sensitive if any crosses alpha; otherwise robust.
#> Specifications reached by two families are counted once; tipping-point grids are searches and are not counted; deletions are
#> counted separately.
#> 
#> 1. Within-subject covariance structure: structures = us, cs, ar1h
#> 2. Degrees-of-freedom method and variance estimator: defaults
#> 3. Covariate set: defaults
#> 4. Least-squares-mean weighting (equal versus observed margins): defaults
#> 5. Leave-one-out deletions: by = RACE
#> 6. Estimator class: estimators = ancova
#> 7. Smallest set of subjects that changes the conclusion: max_k = 2
```
