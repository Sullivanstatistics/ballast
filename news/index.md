# Changelog

## ballast 0.6.1

First CRAN submission.

- Seeded steps (simulation, re-randomisation, multiple imputation,
  robust regression) restore the caller’s random-number state on exit,
  so a `seed` argument never changes the global stream.
- [`stress_report()`](https://sullivanstatistics.github.io/ballast/reference/stress_report.md),
  [`stress_tables()`](https://sullivanstatistics.github.io/ballast/reference/stress_tables.md)
  and
  [`stress_html()`](https://sullivanstatistics.github.io/ballast/reference/stress_html.md)
  have no default output location; nothing is written unless a directory
  or file is given.
- [`stress_verdict()`](https://sullivanstatistics.github.io/ballast/reference/stress_verdict.md)
  and
  [`tipping_point()`](https://sullivanstatistics.github.io/ballast/reference/tipping_point.md)
  gain examples.
- ORCID and copyright-holder role in `Authors@R`; the citation reads the
  version from the package metadata.

## ballast 0.6.0

- [`standard_plan()`](https://sullivanstatistics.github.io/ballast/reference/standard_plan.md)
  now shifts the tipping family at the contrast visit unless
  `shift_visits` is given; before, an omitted `shift_visits` shifted
  every imputed visit, which changed the tipping estimand silently.
- [`stress_design()`](https://sullivanstatistics.github.io/ballast/reference/stress_design.md):
  design-stage use. Simulates a planned trial over a grid of sample
  sizes and effect sizes and reports the robustness power (significant
  and robust) next to the conventional power, the verdict rates among
  significant results, the one-subject fragility, and optionally the
  deletion search and the delta-adjustment margin;
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws power
  and robustness power against the sample size, and
  [`print()`](https://rdrr.io/r/base/print.html) names the smallest
  sample size that reaches a target robustness power.

## ballast 0.5.0

- [`stress_ranktest()`](https://sullivanstatistics.github.io/ballast/reference/stress_ranktest.md):
  Wilcoxon rank-sum and van Elteren tests at the contrast visit
  (model-free family).

- [`simulate_trial()`](https://sullivanstatistics.github.io/ballast/reference/simulate_trial.md)
  gains heavy-tailed errors, heteroscedastic visits, MNAR dropout and
  effect modification;
  [`stress_calibrate()`](https://sullivanstatistics.github.io/ballast/reference/stress_calibrate.md)
  passes them through.

- Observed-margins weighting fixed for three or more arms.

- Reference-based imputation seeds each draw on the worker, so results
  no longer depend on the number of cores.

- The fitter reads the model matrix and covariance parameters through
  mmrm’s public accessors.

- Verdicts, reports and tables state how many refits did not converge.

- [`mask_ids()`](https://sullivanstatistics.github.io/ballast/reference/mask_ids.md)
  replaces subject identifiers with sequence numbers; on by default in
  [`stress_html()`](https://sullivanstatistics.github.io/ballast/reference/stress_html.md).

- [`run_plan()`](https://sullivanstatistics.github.io/ballast/reference/run_plan.md)
  starts one worker cluster and shares it across families.

- [`stress_sap()`](https://sullivanstatistics.github.io/ballast/reference/stress_sap.md)
  and the installed template give the statistical-analysis-plan text for
  a pre-specified stress test.

- Validation vignette; CITATION; Nathan Hogan credited for the SAS
  reference validation.

## ballast 0.4.0

- Specs from an `mmrm` fit
  ([`stress_spec_mmrm()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec_mmrm.md))
  and from an ADaM BDS data set
  ([`stress_spec_adam()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec_adam.md)).
- Three or more arms: `active` chooses the comparison;
  [`stress_visits()`](https://sullivanstatistics.github.io/ballast/reference/stress_visits.md)
  gives the contrast at every visit;
  [`run_plans()`](https://sullivanstatistics.github.io/ballast/reference/run_plans.md)
  runs several endpoints or comparisons and summarises them together.
- [`standard_plan()`](https://sullivanstatistics.github.io/ballast/reference/standard_plan.md):
  the recommended, citable set of families.
- [`stress_estimand()`](https://sullivanstatistics.github.io/ballast/reference/stress_estimand.md):
  intercurrent-event strategies (treatment policy, hypothetical, while
  on treatment, composite) derived from an event table.
- [`stress_explain()`](https://sullivanstatistics.github.io/ballast/reference/stress_explain.md):
  attributes an alternative’s shift to subjects.
- Deliverables:
  [`stress_tables()`](https://sullivanstatistics.github.io/ballast/reference/stress_tables.md)
  (CSV, Word, RTF),
  [`stress_log()`](https://sullivanstatistics.github.io/ballast/reference/stress_log.md)
  (audit trail with the plan’s hash),
  [`stress_html()`](https://sullivanstatistics.github.io/ballast/reference/stress_html.md)
  (interactive report).
- [`simulate_trial()`](https://sullivanstatistics.github.io/ballast/reference/simulate_trial.md)
  and
  [`stress_calibrate()`](https://sullivanstatistics.github.io/ballast/reference/stress_calibrate.md):
  pre-trial calibration of the verdict.
- Vignettes: quickstart, interpreting the verdict, missing data, for SAS
  users.

## ballast 0.3.0

- Pre-specification:
  [`stress_plan()`](https://sullivanstatistics.github.io/ballast/reference/stress_plan.md),
  [`run_plan()`](https://sullivanstatistics.github.io/ballast/reference/run_plan.md),
  [`stress_report()`](https://sullivanstatistics.github.io/ballast/reference/stress_report.md).
- [`stress_weights()`](https://sullivanstatistics.github.io/ballast/reference/stress_weights.md)
  and the `weights` setting (equal versus observed-margins least-squares
  means); cLDA estimator; fast path for the re-randomisation test.
- Validation: rbmi cross-check of the reference-based imputation;
  re-randomisation and cLDA gates.

## ballast 0.2.0

- Reference-based multiple imputation
  ([`stress_reference()`](https://sullivanstatistics.github.io/ballast/reference/stress_reference.md)),
  the sensitivity/supplementary `role`, the greedy deletion search
  ([`stress_fragility()`](https://sullivanstatistics.github.io/ballast/reference/stress_fragility.md)),
  the estimator-class family
  ([`stress_estimator()`](https://sullivanstatistics.github.io/ballast/reference/stress_estimator.md)).

## ballast 0.1.0

- Engine, nine families, census, verdict and the three displays;
  validated against a SAS robustness package.
