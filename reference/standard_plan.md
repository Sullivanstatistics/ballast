# The standard stress test

A recommended, citable set of families with fixed settings, so that a
statistical analysis plan can say "the standard stress test of ballast"
and mean one thing. It contains, in order:

## Usage

``` r
standard_plan(
  spec,
  site = NULL,
  strata = site,
  baseline = NULL,
  deltas = NULL,
  shift_visits = NULL,
  ice = NULL,
  m = 25,
  n_perm = 2000,
  max_k = 5
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- site:

  Optional site or centre column (deletions, random intercept,
  re-randomisation strata unless `strata` is given).

- strata:

  Optional stratification column for the re-randomisation test.

- baseline:

  Optional baseline column for cLDA.

- deltas:

  Optional shifts for the tipping-point family.

- shift_visits:

  Visits whose imputed values the tipping family shifts; `NULL` shifts
  the contrast visit only (the plan text states the visits; pass every
  visit level to shift all imputed values).

- ice:

  Optional intercurrent-event table for
  [`stress_estimand()`](https://sullivanstatistics.github.io/ballast/reference/stress_estimand.md).

- m:

  Imputations for the multiple-imputation families.

- n_perm:

  Permutations for the re-randomisation test.

- max_k:

  Maximum removals in the deletion search.

## Value

A `stress_plan`.

## Details

1.  covariance structure: `us`, `ar1h`, `ar1`, `cs`, `csh`, `toep`,
    `toeph`;

2.  inference: Satterthwaite, Kenward-Roger, linear Kenward-Roger,
    residual, sandwich with between-within df, jackknife sandwich;

3.  covariate set: each covariate dropped, all dropped;

4.  LS-mean weighting: equal and observed margins;

5.  leave-one-out: every subject, and every level of `site` if given;

6.  re-randomisation test: 2,000 permutations, within `strata` if given;

7.  reference-based multiple imputation: MAR, J2R, CR, CIR, 25
    imputations;

8.  delta-adjusted multiple imputation over `deltas` if given;

9.  estimator class: complete cases, GEE independence, ANCOVA, robust
    ANCOVA, plus a random intercept for `site` and cLDA for `baseline`
    if given;

10. greedy deletion search for the loss of significance, up to 5
    subjects;

11. intercurrent-event strategies if `ice` is given (treatment policy,
    hypothetical, while on treatment).

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
standard_plan(spec, site = "RACE", baseline = "FEV1_BL")
#> Standard stress test (ballast 0.6.1)
#> 
#> Pre-specified analysis: FEV1 ~ RACE + SEX + FEV1_BL + ARMCD + AVISIT + ARMCD:AVISIT + us(AVISIT | USUBJID); contrast TRT minus PBO at VIS4; Kenward-Roger df, Kenward-Roger-Linear variance; alpha 0.05; equal LS-mean weights.
#> 
#> Perturbation families, run after unblinding exactly as listed; every refit is judged against the pre-specified estimate,
#> its 95% confidence interval and alpha. Classification: fragile if any counted alternative reverses direction or leaves the
#> pre-specified confidence interval; otherwise sensitive if any crosses alpha; otherwise robust. Specifications reached by two
#> families are counted once; tipping-point grids are searches and are not counted; deletions are counted separately.
#> 
#> 1. Within-subject covariance structure: structures = us, ar1h, ar1, cs, csh, toep, toeph
#> 2. Degrees-of-freedom method and variance estimator: defaults
#> 3. Covariate set: defaults
#> 4. Least-squares-mean weighting (equal versus observed margins): defaults
#> 5. Leave-one-out deletions: defaults | by = RACE
#> 6. Re-randomisation test: n = 2000; strata = RACE
#> 7. Reference-based multiple imputation (MAR, J2R, CR, CIR): m = 25
#> 8. Estimator class: estimators = complete_cases, gee_independence, ancova, robust_ancova, random_intercept, clda; random = RACE; baseline = FEV1_BL
#> 9. Smallest set of subjects that changes the conclusion: target = significance; max_k = 5
```
