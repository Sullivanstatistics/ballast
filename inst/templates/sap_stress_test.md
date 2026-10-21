# Stress test of the primary analysis (template for a statistical analysis plan)

Replace the bracketed items. `ballast::stress_sap(plan)` generates the same text from a plan object, including the plan hash.

**Stress test of the primary analysis (pre-specified).** After database lock and unblinding, the primary analysis of
[trial] will be stress-tested with the ballast R package (version [x.y.z]): the pre-specified model will be refitted under
the families of perturbations listed below, and every refit will be judged against the pre-specified estimate, its 95%
confidence interval and the two-sided significance level of [0.05].

**Pre-specified analysis.** [response] ~ [covariates] + [treatment] + [visit] + [treatment:visit] + [covariance]([visit] | [subject]),
with the treatment contrast [active] minus [reference] at [visit] formed from least-squares means ([equal] weights),
[Satterthwaite] degrees of freedom and the [model-based] variance estimator.

**Perturbation families.** The families and their settings are fixed as follows and will not be changed after unblinding:

- Within-subject covariance structure: [us, ar1h, ar1, cs, csh, toep, toeph]
- Degrees-of-freedom method and variance estimator: [Satterthwaite; Kenward-Roger; linear Kenward-Roger; residual; sandwich with between-within df; jackknife sandwich]
- Covariate set: [each covariate dropped in turn; all dropped]
- Least-squares-mean weighting: [equal; observed margins]
- Leave-one-out deletions: [every subject; every level of [site]]
- Re-randomisation test: [2,000 permutations within [strata]]
- Reference-based multiple imputation: [MAR, J2R, CR, CIR; 25 imputations]
- Delta-adjusted multiple imputation: [shifts of ... applied to the imputed values of the active arm at [visit]; 25 imputations]
- Estimator class: [complete cases; GEE independence with robust variance; ANCOVA at [visit]; MM robust regression; random intercept for [site]; cLDA]
- Smallest set of subjects that changes the conclusion: [target significance; at most 5 removals]
- Intercurrent-event strategies: [treatment policy; hypothetical; while on treatment, for the events listed in Section [x]]

**Counting rule.** A refit that reproduces the pre-specified analysis exactly is not counted. A specification reached by
two families (the same estimate, standard error, degrees of freedom and number of observations) is counted once.
Tipping-point grids and the deletion search are searches and are not counted; the delta-zero multiple-imputation analysis
is counted. Deletions are counted but summarised separately from alternative analyses. Refits that do not converge are
reported and not counted.

**Classification.** The result will be classed *fragile* if any counted alternative lands outside the pre-specified
95% confidence interval (the margin of error); otherwise *sensitive* if any counted alternative
crosses the significance level; otherwise *robust*. The pre-specified p-value will be flagged *marginal* if it lies
between half and twice the significance level. The classification will be reported over all counted refits and over the
sensitivity analyses alone (those that keep the estimand); alternative data sets, populations, other visits and
intercurrent-event strategies are supplementary analyses and will be labelled as such.

**Expected verdict under the design assumptions.** Before unblinding, the planned design ([n] per arm, effect [delta],
residual SD [sigma], correlation [rho], dropout [rate]) was simulated with `ballast::stress_design()` under the
pre-specified model and the families above ([n_trials] trials per cell). The probability of a significant result is
[power] and of a significant and robust result [robustness power]; among significant results, [x]% are expected to be
classed sensitive and [y]% fragile, and one participant's removal is expected to lose significance in [z]% of them. The
observed verdict will be reported next to these expectations.

**Reporting.** The per-family summary, the list of refits that crossed the significance level or left the interval, the
deletion-search path, the full census, the bubble-swarm, deletion-strip and tipping-point figures, and a run log with the
seed, software versions and the hash of this plan will be provided as an appendix to the clinical study report. Subject
identifiers will be masked in any version that leaves the sponsor.

**Plan hash.** MD5 of the plan text as fixed in this document: `[hash from stress_log() or stress_sap()]`. The run log
will carry the same hash.
