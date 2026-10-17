# Package index

## Specify

- [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md)
  : Define the pre-specified MMRM to stress-test
- [`stress_spec_mmrm()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec_mmrm.md)
  : Build a stress spec from a fitted mmrm model
- [`stress_spec_adam()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec_adam.md)
  : Build a stress spec from an ADaM basic data structure
- [`spec_update()`](https://sullivanstatistics.github.io/ballast/reference/spec_update.md)
  : Modify a stress spec
- [`stress_fit()`](https://sullivanstatistics.github.io/ballast/reference/stress_fit.md)
  : Fit one MMRM and return one row

## Perturbation families

- [`stress_covariance()`](https://sullivanstatistics.github.io/ballast/reference/stress_covariance.md)
  : Perturbation family: within-subject covariance structure

- [`stress_inference()`](https://sullivanstatistics.github.io/ballast/reference/stress_inference.md)
  : Perturbation family: degrees-of-freedom method and variance
  estimator

- [`default_inference()`](https://sullivanstatistics.github.io/ballast/reference/default_inference.md)
  :

  Default inference settings for
  [`stress_inference()`](https://sullivanstatistics.github.io/ballast/reference/stress_inference.md)

- [`stress_covariates()`](https://sullivanstatistics.github.io/ballast/reference/stress_covariates.md)
  : Perturbation family: covariate set

- [`stress_weights()`](https://sullivanstatistics.github.io/ballast/reference/stress_weights.md)
  : Perturbation family: least-squares-mean weighting

- [`stress_data()`](https://sullivanstatistics.github.io/ballast/reference/stress_data.md)
  : Perturbation family: alternative analysis data sets

- [`stress_population()`](https://sullivanstatistics.github.io/ballast/reference/stress_population.md)
  : Perturbation family: analysis population

- [`stress_loo()`](https://sullivanstatistics.github.io/ballast/reference/stress_loo.md)
  : Perturbation family: leave-one-out deletions

- [`stress_grid()`](https://sullivanstatistics.github.io/ballast/reference/stress_grid.md)
  : Perturbation family: crossed specification grid

- [`stress_permute()`](https://sullivanstatistics.github.io/ballast/reference/stress_permute.md)
  : Perturbation family: re-randomisation (permutation) test

- [`stress_tipping()`](https://sullivanstatistics.github.io/ballast/reference/stress_tipping.md)
  : Perturbation family: delta-adjusted multiple imputation (tipping
  point)

- [`stress_reference()`](https://sullivanstatistics.github.io/ballast/reference/stress_reference.md)
  : Perturbation family: reference-based multiple imputation

- [`stress_estimator()`](https://sullivanstatistics.github.io/ballast/reference/stress_estimator.md)
  : Perturbation family: estimator class

- [`stress_fragility()`](https://sullivanstatistics.github.io/ballast/reference/stress_fragility.md)
  : Smallest set of subjects whose removal changes the conclusion

- [`stress_curve()`](https://sullivanstatistics.github.io/ballast/reference/stress_curve.md)
  : Perturbation family: a curve over a continuous data perturbation

- [`stress_estimand()`](https://sullivanstatistics.github.io/ballast/reference/stress_estimand.md)
  : Perturbation family: intercurrent-event strategies (ICH E9(R1))

- [`stress_visits()`](https://sullivanstatistics.github.io/ballast/reference/stress_visits.md)
  : Perturbation family: the contrast at every visit

- [`stress_ranktest()`](https://sullivanstatistics.github.io/ballast/reference/stress_ranktest.md)
  : Perturbation family: rank tests at the contrast visit

## Census and verdict

- [`stress_census()`](https://sullivanstatistics.github.io/ballast/reference/stress_census.md)
  : Assemble a census of perturbations against the base analysis
- [`summary(`*`<stress_census>`*`)`](https://sullivanstatistics.github.io/ballast/reference/summary.stress_census.md)
  : Summarise a census by family
- [`stress_verdict()`](https://sullivanstatistics.github.io/ballast/reference/stress_verdict.md)
  : Classify the census: robust, sensitive or fragile, and marginal
- [`tipping_point()`](https://sullivanstatistics.github.io/ballast/reference/tipping_point.md)
  : Find where a p-value curve crosses alpha
- [`stress_explain()`](https://sullivanstatistics.github.io/ballast/reference/stress_explain.md)
  : Explain why an alternative analysis moved

## Pre-specify, run, report

- [`stress_plan()`](https://sullivanstatistics.github.io/ballast/reference/stress_plan.md)
  : Pre-specify a stress test
- [`standard_plan()`](https://sullivanstatistics.github.io/ballast/reference/standard_plan.md)
  : The standard stress test
- [`run_plan()`](https://sullivanstatistics.github.io/ballast/reference/run_plan.md)
  : Run a pre-specified stress test
- [`run_plans()`](https://sullivanstatistics.github.io/ballast/reference/run_plans.md)
  : Run several plans (several endpoints or comparisons) and compare
- [`stress_report()`](https://sullivanstatistics.github.io/ballast/reference/stress_report.md)
  : Write a stress-test report
- [`stress_tables()`](https://sullivanstatistics.github.io/ballast/reference/stress_tables.md)
  : Write regulatory-style tables and the census
- [`stress_log()`](https://sullivanstatistics.github.io/ballast/reference/stress_log.md)
  : Write the run log for an audit trail
- [`stress_html()`](https://sullivanstatistics.github.io/ballast/reference/stress_html.md)
  : Interactive HTML report
- [`stress_sap()`](https://sullivanstatistics.github.io/ballast/reference/stress_sap.md)
  : Statistical-analysis-plan text for a stress test
- [`mask_ids()`](https://sullivanstatistics.github.io/ballast/reference/mask_ids.md)
  : Mask subject identifiers in a census

## Figures

- [`plot(`*`<stress_census>`*`)`](https://sullivanstatistics.github.io/ballast/reference/plot.stress_census.md)
  : Plot a census: one row per family on the percent-of-base axis
- [`plot_swarm()`](https://sullivanstatistics.github.io/ballast/reference/plot_swarm.md)
  : Bubble-swarm plot of a census against the no-difference line
- [`plot_pcurve()`](https://sullivanstatistics.github.io/ballast/reference/plot_pcurve.md)
  : Plot p-value curves over a continuous perturbation
- [`plot_pstrip()`](https://sullivanstatistics.github.io/ballast/reference/plot_pstrip.md)
  : Strip plot of p-values after each deletion

## Calibration

- [`simulate_trial()`](https://sullivanstatistics.github.io/ballast/reference/simulate_trial.md)
  : Simulate a two-arm longitudinal trial
- [`stress_calibrate()`](https://sullivanstatistics.github.io/ballast/reference/stress_calibrate.md)
  : Pre-trial calibration of the stress test
