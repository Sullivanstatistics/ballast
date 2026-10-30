# Statistical-analysis-plan text for a stress test

Returns the paragraphs a statistical analysis plan can carry to
pre-specify a stress test: the purpose, the pre-specified analysis, the
families and their settings (from the plan), the counting rule, the
classification, what will be reported, and the plan's MD5 hash so the
run after unblinding can be shown to match what was pre-specified. The
same text is installed as a template at
`system.file("templates", "sap_stress_test.md", package = "ballast")`.

## Usage

``` r
stress_sap(plan, file = NULL, trial = "the study")
```

## Arguments

- plan:

  A
  [`stress_plan()`](https://sullivanstatistics.github.io/ballast/reference/stress_plan.md).

- file:

  Optional path to write the text to (Markdown).

- trial:

  A short name for the trial, used in the text.

## Value

A character vector of paragraphs, invisibly if `file` is given.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
cat(stress_sap(standard_plan(spec, site = "RACE"), trial = "Study 001"), sep = "\n\n")
#> **Stress test of the primary analysis (pre-specified).** After database lock and unblinding, the primary analysis of Study 001 will be stress-tested with the ballast R package (version 0.7.4): the pre-specified model will be refitted under the families of perturbations listed below, and every refit will be judged against the pre-specified estimate, its 95% confidence interval and the two-sided significance level of 0.05.
#> 
#> **Pre-specified analysis.** FEV1 ~ RACE + SEX + FEV1_BL + ARMCD + AVISIT + ARMCD:AVISIT + us(AVISIT | USUBJID), with the treatment contrast TRT minus PBO at VIS4 formed from least-squares means (equal weights), Kenward-Roger degrees of freedom and the Kenward-Roger-Linear variance estimator.
#> 
#> **Perturbation families.** The families and their settings are fixed as follows and will not be changed after unblinding:
#> 
#> - 1. Within-subject covariance structure: structures = us, ar1h, ar1, cs, csh, toep, toeph
#> 
#> - 2. Degrees-of-freedom method and variance estimator: defaults
#> 
#> - 3. Covariate set: defaults
#> 
#> - 4. Least-squares-mean weighting (equal versus observed margins): defaults
#> 
#> - 5. Leave-one-out deletions: defaults | by = RACE
#> 
#> - 6. Re-randomisation test: n = 2000; strata = RACE
#> 
#> - 7. Reference-based multiple imputation (MAR, J2R, CR, CIR): m = 25
#> 
#> - 8. Estimator class: estimators = complete_cases, gee_independence, ancova, robust_ancova, random_intercept; random = RACE; diagnostic = complete_cases. The complete cases refit is fitted, drawn and tabulated as a diagnostic and is not counted.
#> 
#> - 9. Smallest set of subjects that changes the conclusion: target = significance; max_k = 5
#> 
#> **Counting rule.** A refit that reproduces the pre-specified analysis exactly is not counted. A specification reached by two families (the same estimate, standard error, degrees of freedom and number of observations) is counted once. Tipping-point grids and the deletion search are searches and are not counted; the delta-zero multiple-imputation analysis is counted. Deletions are counted but summarised separately from alternative analyses. Refits that do not converge are reported and not counted. Refits the plan marks as diagnostic (in the standard stress test, the pre-specified model on complete cases) are fitted, drawn and tabulated with their status but are not counted and do not enter the classification.
#> 
#> **Classification.** The result will be classed *fragile* if any counted refit (an alternative analysis or a deletion) lands outside the pre-specified 95% confidence interval; otherwise *sensitive* if any counted refit crosses the significance level; otherwise *robust*. The pre-specified p-value will be flagged *marginal* if it lies between half and twice the significance level. The classification will be reported over all counted refits and over the sensitivity analyses alone (those that keep the estimand); alternative data sets, populations, other visits and intercurrent-event strategies are supplementary analyses and will be labelled as such.
#> 
#> **Reporting.** The per-family summary (analyses, significant, crossed, outside the interval, reversed, range as a percentage of the pre-specified estimate, largest shift in pre-specified standard errors), the list of refits that crossed the significance level or left the interval, the deletion-search path, the full census, the bubble-swarm, deletion-strip and tipping-point figures, and a run log with the seed, software versions and the hash of this plan will be provided as an appendix to the clinical study report. Subject identifiers will be masked in any version that leaves the sponsor.
#> 
#> **Plan hash.** MD5 of the plan text as fixed in this document: `a96eb03a333c4a04547e1534f0ab412f`. The run log will carry the same hash.
```
