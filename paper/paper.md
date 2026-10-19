---
title: 'ballast: stress-test a pre-specified mixed model for repeated measures'
tags:
  - R
  - clinical trials
  - mixed models
  - sensitivity analysis
  - estimands
  - missing data
  - reproducibility
authors:
  - name: Adam J. Sullivan
    orcid: 0000-0002-9429-3611
    corresponding: true
    affiliation: 1
  - name: Nathan Hogan
    affiliation: 1
affiliations:
  - name: Capricor Therapeutics, San Diego, CA, United States
    index: 1
date: 18 October 2026
bibliography: paper.bib
---

# Summary

A confirmatory clinical trial with a continuous endpoint measured over time is usually analysed by one pre-specified
mixed model for repeated measures (MMRM). That one model embodies many decisions: the within-subject covariance
structure, the degrees-of-freedom method and variance estimator, the covariate set, the weighting of the least-squares
means, the analysis population, the handling of intercurrent events, the missing-data assumption and the class of
estimator. When a result sits near the significance threshold, reviewers ask whether it survives each of them.

`ballast` answers that question in one run. It refits the pre-specified model under families of perturbations of these
decisions and of the data, scores every refit against the pre-specified estimate, confidence interval and significance
level, and classifies the finding as *robust*, *sensitive* or *fragile*, with a separate flag for *marginal* significance.
A counting rule fixes what "N alternative analyses" means, every refit carries its ICH E9(R1) role (sensitivity or
supplementary analysis), and a greedy deletion search gives a fragility-index analogue for continuous longitudinal
endpoints. The families, their settings and the verdict rule are fixed in a plan object whose hash is written to the run
log, so the test can be pre-specified in a statistical analysis plan before unblinding and shown afterwards to match. The
same machinery runs on simulated trials at the design stage to give the *robustness power* of a design, the probability
that a true effect is significant and robust, next to its conventional power.

# Statement of need

The tools for this question exist in pieces. Reference-based and delta-adjusted multiple imputation vary the missing-data
assumption [@carpenter2013; @rbmi]; the fragility index counts events that would have to change for binary outcomes
[@walsh2014]; multiverse and specification-curve analysis enumerate the analyses a researcher could have run
[@steegen2016; @simonsohn2020]; influence diagnostics measure each subject's leverage. None anchors every alternative to
one pre-specified result, spans the modelling, inference, data and missing-data decisions in one census with a stated
counting rule, classifies the outcome in terms a regulator can act on, has published operating characteristics, and can
be pre-specified. Sponsors assemble such censuses by hand, in weeks, when a review demands one; the package was written
after one such review, in which a census of about nine hundred re-analyses took a month in SAS and the word *fragile*
was used without a definition.

`ballast` is for the biostatistician who must answer "is the result robust?" for an MMRM, before or after unblinding,
and for the reviewer who wants the answer on a stated rule. It is built on `mmrm` [@mmrm] and reproduces the SAS
`PROC MIXED` conventions that filed analyses follow (the Kenward-Roger adjustment as the linear Kenward-Roger variance,
between-within degrees of freedom under a sandwich variance, equal-weight least-squares means, the REML corrected Akaike
criterion), and its multiple imputation follows `PROC MI`, so that a filed analysis reproduces exactly before it is
perturbed.

# Functionality

A `stress_spec()` fixes the pre-specified analysis: data, response, subject, visit, treatment and reference, covariates,
contrast visit, covariance structure, degrees-of-freedom method and variance estimator. Specs can also be built from a
fitted `mmrm` model or from a CDISC ADaM basic data structure. Seventeen perturbation families return rows in one
schema: covariance structures; inference methods; covariate sets; least-squares-mean weighting; crossed specification
grids; alternative data sets and populations; leave-one-out deletions by subject and by group; re-randomisation tests;
delta-adjusted multiple imputation (tipping point); reference-based multiple imputation under MAR, jump to reference,
copy reference and copy increments in reference; an estimator class (complete cases, GEE with working independence,
ANCOVA, MM-type robust regression, a site random intercept, constrained longitudinal data analysis); the greedy deletion
search for significance, the interval or the direction; intercurrent-event strategies for named participants; contrasts
at other visits; rank tests; and any user-defined continuous perturbation curve.

`stress_census()` applies the counting rule and scores each row; `stress_verdict()` classifies. `standard_plan()` names
the recommended family set, `stress_plan()` builds any other, `run_plan()` runs it on a shared worker cluster, and
`stress_report()`, `stress_tables()`, `stress_html()`, `stress_log()` and `stress_sap()` write the Markdown report with
figures, Word and RTF tables, an interactive HTML version with masked identifiers, a JSON audit log carrying the plan hash,
seed and software versions, and the analysis-plan text. Figures include a bubble swarm of distinct estimates against the
no-difference line, leave-one-out p-value strips, p-value curves over a shift, and the empirical distribution of the
census p-values against the uniform. `simulate_trial()`, `stress_calibrate()` and `stress_design()` give the design-stage
use: verdict rates and robustness power for a planned design over a grid of sample sizes and effects.

# Validation

The package was validated in a chain. A 47-program SAS robustness package for a phase 3 trial, independently reviewed,
was ported program by program to R and checked cell by cell; `ballast` was then checked against the port on about 1,250
cells across seven gates, including the full submitted census of 360 alternative analyses and 553 deletions, with
deterministic quantities agreeing to $10^{-6}$ on the estimate and standard error and Monte Carlo quantities within Monte
Carlo error. Reference-based imputation agrees with `rbmi` on its public antidepressant data under all four assumptions.
Simulation studies of 2,750 trials establish the operating characteristics of the classification; they and the
validation gates are documented in the package vignettes. The package has 278 tests and is checked on Windows, macOS and
Linux on every push.

# AI usage disclosure

The software, tests, documentation and this paper were developed with the assistance of Claude (Anthropic), an AI coding
and writing tool, under the direction of the authors, who specified the methods, made the design decisions, reviewed all
code and text, and take responsibility for them. Correctness was established independently of the tool through the
validation chain described above.

# Acknowledgements

The authors thank the clinical, data management and programming teams of the trial whose review prompted this work,
and the authors of `mmrm` and `rbmi`, on which the implementation and its validation rest. Both authors are employees of
Capricor Therapeutics.

# References
