# Validation summary

This vignette records how ballast was validated, for users who need to
qualify it under their own procedures. The comparisons were made against
two independent references: a SAS robustness package for a phase 3 trial
(47 programs, run under SAS 9.4 and independently reviewed), ported
program by program to R and checked cell by cell before the generic
package was written; and rbmi, the reference R implementation of
reference-based multiple imputation, on the public antidepressant data
set it ships. Trial-level numbers from the SAS reference are not
reproduced here; the comparison tables with every cell are held by the
maintainer.

## Tolerances

Deterministic quantities: estimate and standard error within 1e-6,
degrees of freedom within 1e-3, p-value within 1e-8, AICc within 1e-4,
numbers of subjects and observations exact. Monte Carlo quantities
(multiple imputation, re-randomisation tests, MM-type robust regression
with a random start): agreement within Monte Carlo error, judged by the
standardised difference against the pooled Monte Carlo standard errors
(\|z\| \< 3).

## Gates against the SAS reference

| Gate | Family | Cells | Result |
|----|----|----|----|
| 1 | Pre-specified analyses, four endpoint-metric pairs ([`stress_fit()`](https://sullivanstatistics.github.io/ballast/reference/stress_fit.md)) | 4 | all within tolerance |
| 1 | Covariance panel: seven structures, Satterthwaite, Kenward-Roger (linear) and sandwich with between-within df ([`stress_covariance()`](https://sullivanstatistics.github.io/ballast/reference/stress_covariance.md), [`stress_inference()`](https://sullivanstatistics.github.io/ballast/reference/stress_inference.md), [`stress_grid()`](https://sullivanstatistics.github.io/ballast/reference/stress_grid.md)) | 10 | all within tolerance, including the between-within df of 302 and the linear Kenward-Roger cell |
| 2 | Specification curve: five covariate sets by three covariances by two df methods by two analysis sets by five endpoint-metric pairs ([`stress_grid()`](https://sullivanstatistics.github.io/ballast/reference/stress_grid.md)) | 300 | all within tolerance |
| 3 | Leave-one-out deletions: every subject and every pooled site group on five endpoint-metric pairs ([`stress_loo()`](https://sullivanstatistics.github.io/ballast/reference/stress_loo.md)) | 553 | all within tolerance |
| 4 | Delta-adjusted multiple imputation, 13 deltas, 25 imputations ([`stress_tipping()`](https://sullivanstatistics.github.io/ballast/reference/stress_tipping.md)) | 13 | within Monte Carlo error, max |
| 5 | Estimator class: GEE independence with cluster sandwich, site random intercept, complete cases, ANCOVA at the contrast visit, MM robust regression ([`stress_estimator()`](https://sullivanstatistics.github.io/ballast/reference/stress_estimator.md)) | 5 | all within tolerance (the MM fit exactly, with the same seed) |
| 6 | Re-randomisation test, 20,000 permutations within strata, two scales ([`stress_permute()`](https://sullivanstatistics.github.io/ballast/reference/stress_permute.md)) | 2 | within Monte Carlo error, |
| 6 | cLDA with baseline as an outcome (`stress_estimator("clda")`) | 1 | within tolerance |
| 7 | The full submitted census: every alternative analysis of the SAS package reproduced through the package’s own functions ([`stress_data()`](https://sullivanstatistics.github.io/ballast/reference/stress_data.md), [`stress_covariates()`](https://sullivanstatistics.github.io/ballast/reference/stress_covariates.md), [`stress_grid()`](https://sullivanstatistics.github.io/ballast/reference/stress_grid.md), [`stress_estimator()`](https://sullivanstatistics.github.io/ballast/reference/stress_estimator.md), [`stress_ranktest()`](https://sullivanstatistics.github.io/ballast/reference/stress_ranktest.md), [`stress_tipping()`](https://sullivanstatistics.github.io/ballast/reference/stress_tipping.md), [`stress_reference()`](https://sullivanstatistics.github.io/ballast/reference/stress_reference.md)) | 360 | 355 exact; 5 multiple-imputation rows within Monte Carlo error |

The port itself had been validated against the SAS master table under
the same tolerances, so the chain is SAS to port to package.

## Cross-check against rbmi

Reference-based imputation was compared with rbmi 1.7.0 on the
antidepressant data (172 subjects, four visits, 80 missing values). Both
engines used the same imputation model (treatment by visit, baseline,
unstructured covariance common to the arms), the same number of
bootstrap draws (100), the same intercurrent-event rule (the first
missing visit after the last observed one), and the same analysis model
applied to both sets of completed data sets, so the comparison isolates
the imputation step.

| Assumption | ballast | rbmi  | z     |
|------------|---------|-------|-------|
| MAR        | -2.87   | -2.82 | -0.76 |
| J2R        | -2.27   | -2.21 | -1.21 |
| CR         | -2.41   | -2.49 | 1.62  |
| CIR        | -2.60   | -2.58 | -0.48 |

The observed-data MMRM under MAR gave -2.87. One caution for rbmi users:
`rbmi::set_vars()` adds only the main effects of group and visit, so the
treatment-by-visit interaction must be named in `covariates`, or the
imputation model understates late-visit contrasts.

## Conventions needed to agree with SAS

- `DDFM=KR` is mmrm’s `method = "Kenward-Roger"` with
  `vcov = "Kenward-Roger-Linear"`; mmrm’s full Kenward-Roger vcov gives
  a smaller standard error.
- `EMPIRICAL` with Satterthwaite or KR falls back to between-within
  degrees of freedom, computed as observations minus subjects minus the
  rank of the within-subject design columns (`sas_conventions = TRUE`).
- Least-squares means weight class covariates equally over their levels
  and set continuous covariates to their means.
- AICc uses the SAS REML definition with the number of covariance
  parameters and N minus the rank of X.
- A class covariate with one level in a subset is dropped from the
  model, as PROC MIXED zeroes it.
- `MNAR ADJUST` under FCS adds the shift at every draw, so it propagates
  through later imputed visits.

## Reproducibility

Every random-number-based family seeds per item (per imputation, per
permutation) on the worker that draws it, so a result is the same for
any number of cores. The run log written by
[`stress_log()`](https://sullivanstatistics.github.io/ballast/reference/stress_log.md)
records the seed, the package and R versions, the platform and the MD5
hash of the plan text.

## Test suite

`R CMD check --as-cran` passes with no errors or warnings on Windows,
macOS and Linux (release and development R) on every push, through
GitHub Actions. The unit tests use
[`mmrm::fev_data`](https://openpharma.github.io/mmrm/latest-tag/reference/fev_data.html)
and emmeans as an oracle for the least-squares-mean contrast.

``` r

# the tests can be run from an installed copy with
testthat::test_package("ballast")
```
