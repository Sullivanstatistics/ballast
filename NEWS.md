# ballast 0.6.0

* `standard_plan()` now shifts the tipping family at the contrast visit unless `shift_visits` is given; before, an omitted `shift_visits` shifted every imputed visit, which changed the tipping estimand silently.
* Seeded steps (simulation, re-randomisation, multiple imputation, robust regression) restore the caller's random-number state on exit, so a `seed` argument never changes the global stream.
* `stress_report()`, `stress_tables()` and `stress_html()` have no default output location; nothing is written unless a directory or file is given.
* `stress_verdict()` and `tipping_point()` gain examples.
* `stress_design()`: design-stage use. Simulates a planned trial over a grid of sample sizes and effect sizes and reports the robustness power (significant and robust) next to the conventional power, the verdict rates among significant results, the one-subject fragility, and optionally the deletion search and the delta-adjustment margin; `plot()` draws power and robustness power against the sample size, and `print()` names the smallest sample size that reaches a target robustness power.

# ballast 0.5.0

* `stress_ranktest()`: Wilcoxon rank-sum and van Elteren tests at the contrast visit (model-free family).
* `simulate_trial()` gains heavy-tailed errors, heteroscedastic visits, MNAR dropout and effect modification; `stress_calibrate()` passes them through.
* Observed-margins weighting fixed for three or more arms.

* Reference-based imputation seeds each draw on the worker, so results no longer depend on the number of cores.
* The fitter reads the model matrix and covariance parameters through mmrm's public accessors.
* Verdicts, reports and tables state how many refits did not converge.
* `mask_ids()` replaces subject identifiers with sequence numbers; on by default in `stress_html()`.
* `run_plan()` starts one worker cluster and shares it across families.
* `stress_sap()` and the installed template give the statistical-analysis-plan text for a pre-specified stress test.
* Validation vignette; CITATION; Nathan Hogan credited for the SAS reference validation.

# ballast 0.4.0

* Specs from an `mmrm` fit (`stress_spec_mmrm()`) and from an ADaM BDS data set (`stress_spec_adam()`).
* Three or more arms: `active` chooses the comparison; `stress_visits()` gives the contrast at every visit;
  `run_plans()` runs several endpoints or comparisons and summarises them together.
* `standard_plan()`: the recommended, citable set of families.
* `stress_estimand()`: intercurrent-event strategies (treatment policy, hypothetical, while on treatment, composite)
  derived from an event table.
* `stress_explain()`: attributes an alternative's shift to subjects.
* Deliverables: `stress_tables()` (CSV, Word, RTF), `stress_log()` (audit trail with the plan's hash),
  `stress_html()` (interactive report).
* `simulate_trial()` and `stress_calibrate()`: pre-trial calibration of the verdict.
* Vignettes: quickstart, interpreting the verdict, missing data, for SAS users.

# ballast 0.3.0

* Pre-specification: `stress_plan()`, `run_plan()`, `stress_report()`.
* `stress_weights()` and the `weights` setting (equal versus observed-margins least-squares means); cLDA estimator;
  fast path for the re-randomisation test.
* Validation: rbmi cross-check of the reference-based imputation; re-randomisation and cLDA gates.

# ballast 0.2.0

* Reference-based multiple imputation (`stress_reference()`), the sensitivity/supplementary `role`,
  the greedy deletion search (`stress_fragility()`), the estimator-class family (`stress_estimator()`).

# ballast 0.1.0

* Engine, nine families, census, verdict and the three displays; validated against a SAS robustness package.
