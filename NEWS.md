# ballast 0.7.4

First update after the CRAN release of 0.6.1; the entries for 0.7.0 to 0.7.3 below list everything else that changed since then. No computation changes: every estimate, interval, p-value and verdict is the same as in 0.7.3.

* `plot_swarm()` no longer changes the caller's random-number state: the multi-row form called `set.seed()` for its cosmetic vertical scatter. It, the bubble swarm, `plot_pstrip()`, `plot()` of a census and the deletion strips of `stress_html()` drew their scatter from the caller's stream; all now seed a stream of their own and restore the caller's state, so each figure is also the same every time it is drawn.
* `plot_swarm()`, multi-row form: each panel labels its own filed estimate and interval ends to three significant digits. Before, the labels were formatted over all panels at once, so a panel took the digits of the longest number in the figure (0.473 printed as 0.47338).
* `plot_swarm()`: `reference` and `reference_label` take one value per row (named by row, or in row order; `NA` for none) as well as one value for every panel, so rows on different scales, such as points and percent change, can each carry their own reference line.
* `plot_pstrip()` gains `highlight`, the labels of deletion rows to ring and label (the participant whose removal crosses alpha, say), and `seed` for the vertical scatter. The scatter is now computed by the package, so a ring falls on the dot it marks.
* `plot_pcurve()` takes a named list of rows, censuses or results and draws one panel per element, with the crossings found within each panel; before, crossings were found by family over all the rows given, so a faceted figure repeated them in every panel. Several crossing labels in one panel are stacked rather than overprinted. Gains `ncol`.
* The classification rule is worded as `stress_verdict()` applies it. The plan text, `stress_sap()`, the SAP template and the interpreting vignette said "any counted alternative"; the verdict has always judged every counted refit, deletions included. They now say "any counted refit (an alternative analysis or a deletion)", for both the fragile and the sensitive label.
* `stress_reference()` documents that imputation `i` is seeded with `seed + i`, so seeds less than `m` apart share imputations, and that a Monte Carlo check by repeating the analysis needs seeds at least `m` apart. `stress_tipping()` documents that its imputations come from one stream, so any two seeds give unrelated imputations.
* `NEWS.md`: the pkgdown entry of the 0.7.3 tag is moved from the 0.7.2 heading to 0.7.3. README: installation from CRAN, and the citation uses the Zenodo concept DOI, which resolves to the latest version.

# ballast 0.7.3

* `standard_plan()`: the complete-case refit of the estimator family is now a diagnostic. It is fitted, drawn on the swarm (as a hollow dot) and on the family plot (as a triangle), and listed in the census and the tables with `kind = "diagnostic"` and `counted = FALSE`; it does not enter the verdict, the crossing count, the outside-interval count or the reversal count. The plan text, `stress_sap()` and the installed SAP template say so. `stress_estimator()` gains `diagnostic`, the names of estimators to treat this way; called directly without it, it still counts every estimator, including complete cases.
* `summary()` of a census gains a `counted` column and one line per diagnostic family, left out of the closing totals; `stress_verdict()` reports `n_diagnostic` and prints it; the family table of `stress_tables()` and `stress_report()` shows the counted status.
* `plot_swarm()` lists every family name the package produces in its decision groups, so "Other family" can appear only for a user-defined family. A test runs the standard plan on `mmrm::fev_data` and checks the swarm legend and the diagnostic row.
* `plot_swarm()`: the hollow diagnostic layer is kept out of the legend, so the colour keys show filled dots again; 0.7.3 as first tagged (e607489) drew a ring over every key. No computation changes. The `v0.7.3` tag now points to the commit with this entry, which contains the code that produced the methods-paper simulations (28be8fb).
* Documentation site: `stress_direction()` is listed in the pkgdown reference index and `DESCRIPTION` gives the site URL; without them the site build failed for the 0.7.1 and 0.7.3 releases. No code changes. The `v0.7.3` tag now points to the commit with this entry. (Until 0.7.4 this entry stood under 0.7.2 by mistake.)

# ballast 0.7.2

* `plot_swarm()`: the re-randomisation test row is coloured as a statistical decision; 0.7.1 placed it under "Other family". No computation changes.

# ballast 0.7.1

The package's surface now matches the methods paper: a stress test that refits one pre-specified MMRM under families of perturbations and displays every refit against the filed result. Nothing is calibrated and no benchmark is computed.

* Removed `deletion_benchmark()`, `removal_ratio()`, `expected_crossing()` and `expected_exit()`, with their documentation and tests.
* `stress_direction()` is cut down. For a filed result that is not significant it reports how many pre-specified re-analyses reverse the direction of the estimate and which, how many move the estimate outside the filed interval, and the number of participants the deletion search removes before the direction reverses (`method = "ranked"` by default, `"greedy"` on request). The standard-normal benchmark, the ratio and the printed reading paragraph are gone; the print method lists the counts and the rows.
* `stress_fragility()` keeps its three targets (`"significance"`, `"ci"`, `"direction"`) and its two methods; the `"mutual"` target is removed.
* `plot_swarm()` gains a multi-row form: given a list of `stress_result` objects (what `run_plans()` returns) or of censuses, it draws one panel per row with the filed estimate and 95% interval as the axis, every counted alternative analysis as a dot coloured by decision group (statistical or data-handling) and the counted deletions as a strip beneath, a line at zero and an optional labelled reference line. Rows without an estimate (rank tests) are counted in the `caption` attribute. The single-census bubble swarm is unchanged.
* `plot_forest()` is new: a forest of estimate and interval for the filed analysis and the supplementary rows (or any named rows), one panel per endpoint-metric, with several results objects side by side in different colours.
* `plot_pcdf()` accepts `stress_result` objects and lists of them as well as censuses.
* `stress_calibrate()` is unchanged: it simulates trials from a planned design and reports verdict rates; it sets no threshold.
# ballast 0.7.0

* `stress_direction()`: direction stability for a result that misses significance, as a small rare-disease trial with a real effect may. Reports whether any pre-specified re-analysis in a census reverses the direction of the estimate or moves it outside its margin of error, and the number of participants whose removal reverses it (the ranked deletion search) against the reversal benchmark of `deletion_benchmark()`. The print method states that the report describes the strength and stability of the evidence and cannot tell a real effect from a chance finding at the same z.
* Seeded steps now draw with R's default generators (Mersenne-Twister, Inversion, Rejection) whatever the caller's `RNGkind()`, and restore the caller's kind and state on exit. A seed therefore gives the same data and imputations in a plain session and on parallel workers (future/furrr with `seed = TRUE` switch the kind to L'Ecuyer-CMRG, which previously changed every seeded result). Results in a default session are unchanged.
* `path_changes()` gains `delta_adjusted`: delta-adjusted imputation under MAR as an analytic change, in the reference-based imputation family (a path uses at most one missing-data assumption) and flagged `assumption_dependent` when it carries a path.
* `simulate_rare_trial()` gains `defect = "allocation"` (with `fast_to_active`): allocation that depends on prognosis, so an analysis omitting the fast-progressor stratum is biased.
* `stress_reference()` shares the bootstrap refit and the standard-normal draws across methods within an imputation (common random numbers). A method's rows are now the same whether it is requested alone or with others, and `delta` is exactly a shift of the imputed values. Imputations for a given seed differ from those of 0.6.1.
* `stress_path()` does no repeated work: the imputation draws are made once per imputation model and reused by every change that leaves the model alone, a state reached twice is fitted once (the first step serves both directions), and the second direction is searched only as far as it could still beat the first. The search is unchanged in what it returns for the winning path.
* **Classification rule.** `stress_verdict()` gains `rule`. The default, `"interval"`, calls a result *fragile* only when a counted re-analysis lands outside the pre-specified 95% confidence interval (the margin of error). For a significant result this is the same as before, because a reversed estimate always lies outside an interval that excludes zero. For a non-significant result a sign change of an estimate near zero is no longer fragile. `rule = "interval_or_direction"` gives the 0.6 behaviour. `stress_plan()`, `stress_design()` and `stress_calibrate()` take the same argument; the plan text, `stress_sap()` and the installed SAP template state the rule; plans saved by 0.6 keep the old rule; verdicts print the rule they used.
* `simulate_rare_trial()`: a small two-arm trial with rare-disease features (a mixture of fast and slow progressors with a random slope and a progression-dependent effect, heavy-tailed errors, sites, dropout) and optional planted defects (outlying participants, an effect carried by one site, informative dropout). It is the generator of the methods paper's simulation studies; `simulate_trial()` is unchanged, so earlier simulations still reproduce.
* `expected_crossing()` and `expected_exit()`: first-order probabilities that one re-analysis crosses the significance level, which depend on where the p-value sits, and that it leaves the pre-specified interval, which do not.
* `stress_path()` and `path_changes()`: the analytic axis of the margin-of-error definition. A greedy search for the fewest analytic changes, made together and each family at most once (covariance, inference, covariates, weighting, reference-based imputation, alternative data sets), that move the estimate outside the pre-specified interval; reports the count `j`, the path, and whether it ran through a reference-based imputation (`assumption_dependent`). Inference changes move only the standard error, so they can make a result sensitive but never move it out of the interval.
* `deletion_benchmark()` and `removal_ratio()`: the data axis. The number of deletions a trial with normally distributed influences would need to leave the interval (and, given z, to lose significance or reverse), and the observed `k_ci` as a fraction of it.
* `stress_fragility()` gains `method = "ranked"`: subjects ranked once by their single-deletion influence and removed together, top 1, 2, ..., k, one refit per step (about n + k refits against about k * n for the greedy search), which makes deletion counts practical for large trials and is the quantity `deletion_benchmark()` approximates. The greedy search remains the default.
* `stress_fragility()` gains `target = "mutual"`: the refit and the pre-specified result are incompatible when either interval excludes the other estimate. It is the data axis of the margin-of-error definition, because one outlying participant widens the pre-specified interval it would otherwise be judged by; in the methods-paper simulations the mutual target detected a single 10-SD data error in 93% of significant trials against 14% for the interval target, at about a 5% false-alarm rate.

# ballast 0.6.1

First CRAN submission.

* Seeded steps (simulation, re-randomisation, multiple imputation, robust regression) restore the caller's random-number state on exit, so a `seed` argument never changes the global stream.
* `stress_report()`, `stress_tables()` and `stress_html()` have no default output location; nothing is written unless a directory or file is given.
* `stress_verdict()` and `tipping_point()` gain examples.
* ORCID and copyright-holder role in `Authors@R`; the citation reads the version from the package metadata.

# ballast 0.6.0

* `standard_plan()` now shifts the tipping family at the contrast visit unless `shift_visits` is given; before, an omitted `shift_visits` shifted every imputed visit, which changed the tipping estimand silently.
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
