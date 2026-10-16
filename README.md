# ballast <img src="man/figures/logo.png" align="right" height="139" alt="ballast hex sticker" />

ballast keeps a result steady under load. It stress-tests a pre-specified mixed model for repeated measures (MMRM):
the model is refitted under families of data and analytic perturbations, and every refit is judged against the
pre-specified estimate, confidence interval and p-value.

```r
library(ballast)
spec <- stress_spec(mmrm::fev_data, response = "FEV1", subject = "USUBJID", visit = "AVISIT",
                    treatment = "ARMCD", reference = "PBO", covariates = ~ RACE + SEX + FEV1_BL,
                    contrast_visit = "VIS4", covariance = "us",
                    method = "Kenward-Roger", vcov = "Kenward-Roger-Linear")   # SAS DDFM=KR
stress_fit(spec)                                   # the pre-specified analysis, one row
# or from a fitted model / an ADaM BDS: stress_spec_mmrm(fit, reference = "PBO"); stress_spec_adam(adeff, "PARAM1")

cen <- stress_census(spec,
  stress_covariance(spec),                         # us, ar1h, ar1, cs, csh, toep, toeph
  stress_inference(spec),                          # Satterthwaite, KR, linear KR, residual, sandwich, jackknife
  stress_covariates(spec),                         # drop each covariate, drop all
  stress_population(spec, list(female = function(d) d$SEX == "Female")),
  stress_loo(spec, by = "RACE"),                   # leave-one-group-out
  stress_permute(spec, n = 500),                   # re-randomisation p
  stress_tipping(spec, deltas = seq(0, -10, -2)),  # delta-adjusted MI (FCS regression)
  stress_reference(spec),                          # MAR, J2R, CR, CIR reference-based MI
  stress_estimator(spec, random = "SITE"),         # complete cases, GEE independence, ANCOVA, robust ANCOVA, random intercept
  stress_fragility(spec, "significance"),          # smallest subject set whose removal flips significance (greedy)
  stress_weights(spec))                            # equal vs observed-margins LS-mean weighting
summary(cen)          # per-family table: counted, significant, crossed, outside CI, reversed, % of base
stress_verdict(cen)   # robust / sensitive / fragile, with a marginal flag
plot(cen)             # one row per family on the percent-of-base axis
plot_swarm(cen)       # bubble swarm of distinct estimates against the no-difference line, deletions beneath
plot_pstrip(cen)      # leave-one-out p-values on a log axis, the base as a diamond
tp <- stress_tipping(spec, deltas = seq(0, -10, -2))
tipping_point(tp)     # interpolated crossing of alpha
plot_pcurve(tp)       # p-value curve over the shift, anchor and crossing marked
# any continuous data perturbation: stress_curve(spec, values, modify = function(data, value) ...)

# the recommended set, pre-specified, run and reported in one go
plan <- standard_plan(spec, site = "SITE", strata = "SITE", baseline = "BASE", deltas = seq(0, -10, -2))
res <- run_plan(plan, cores = 6)
stress_report(res, dir = "stress")    # Markdown + figures
stress_tables(res, dir = "stress")    # CSV, Word, RTF
stress_html(res, "stress/report.html") # interactive
stress_log(res, "stress/log.json")    # audit trail with the plan hash

# or build your own plan
plan <- stress_plan(spec, loo = list(list(), list(by = "SITE")), tipping = list(deltas = seq(0, -10, -2)),
                    estimator = list(random = "SITE", baseline = "BASE"))
plan                                  # SAP-ready text
res <- run_plan(plan, cores = 6)
stress_report(res, dir = "stress")    # Markdown report with the figures
```

## Definitions

- **Fragile**: some counted alternative reverses the direction of the estimate or lands outside the pre-specified
  95% confidence interval.
- **Sensitive**: some counted alternative crosses alpha while keeping the direction and staying inside the interval.
- **Robust**: no counted alternative crosses alpha.
- **Marginal** (separate flag): the pre-specified p-value lies near alpha.

## Roles

Every row carries `role`: `"sensitivity"` for an analysis that keeps the estimand and changes an assumption or modelling
choice, `"supplementary"` for one that targets a different estimand (ICH E9(R1)). Alternative data sets and populations
default to supplementary; everything else to sensitivity. The verdict is reported over all counted rows and over the
sensitivity rows alone.

## Counting rule

Rows that reproduce the pre-specified analysis exactly (`is_base`) are not counted, and a specification reached by two
families (the same estimate, standard error, degrees of freedom and observation count) is counted once. Tipping-point grids are searches
(`kind = "search"`) and are not counted; the delta-zero multiple-imputation row is. Leave-one-out deletions are counted
but summarised separately from alternative analyses (`kind = "deletion"`).

## Conventions

The treatment contrast is an explicit least-squares-mean vector with SAS `LSMEANS` conventions (class covariates at
equal weights, continuous covariates at their means), evaluated with `mmrm::df_1d`. `method = "Kenward-Roger"` with
`vcov = "Kenward-Roger-Linear"` reproduces SAS `DDFM=KR`; `method = "Between-Within"` with `vcov = "Empirical"`
reproduces `EMPIRICAL`. AICc uses the SAS REML definition. The multiple imputation follows PROC MI (FCS regression
method, `MNAR ADJUST` applied at every draw) and PROC MIANALYZE.

## Status

Development skeleton, 16 Oct 2026. The engine is a generic rewrite of a program-by-program validated R port of a SAS
robustness package; the generic version is validated against that port's anchor analyses locally (not shipped).
