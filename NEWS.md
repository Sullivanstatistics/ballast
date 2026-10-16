# ballast 0.4.0 (development, 16 October 2026)

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
