# Classify the census: robust, sensitive or fragile, and marginal

Applies the definitions: *fragile* if any counted row lies outside the
base 95% confidence interval (the margin-of-error rule, the default from
0.7.0); otherwise *sensitive* if any counted row changes significance at
`alpha`; otherwise *robust*. *Marginal* is a separate flag on the base
p-value, true when it lies within `alpha * marginal_band`.

## Usage

``` r
stress_verdict(
  census,
  marginal_band = c(0.5, 2),
  rule = c("interval", "interval_or_direction")
)
```

## Arguments

- census:

  A `stress_census`.

- marginal_band:

  Multiplicative band around `alpha` for the marginal flag; the default
  flags a base p between `alpha / 2` and `2 * alpha`.

- rule:

  `"interval"` (default): fragile means outside the base confidence
  interval. `"interval_or_direction"`: outside the interval or a
  reversed direction (the rule of ballast 0.6 and earlier).

## Value

A list of class `stress_verdict`: `stability` over every counted row,
`stability_sensitivity` over the rows that keep the estimand
(`role = "sensitivity"`), `marginal`, `rule`, the counts behind them,
and the rows that drove the classification.

## Details

For a significant base result the interval excludes zero, so a refit
that reverses the direction always lies outside it and the two rules
agree. They differ only for a non-significant base result: there a sign
change of an estimate near zero is a small move inside the interval, and
the default rule does not call it fragile.
`rule = "interval_or_direction"` restores the 0.6 behaviour, in which
any reversal is fragile.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
cen <- stress_census(spec, stress_covariance(spec, c("us", "cs")), stress_covariates(spec))
v <- stress_verdict(cen)
v$stability
#> [1] "robust"
v
#> Base: estimate 4.4, 95% CI 1.09 to 7.71, p = 0.00948 (alpha 0.05)
#> Counted: 5 alternative analyses, 0 deletions; 5 significant, 0 crossed alpha
#> Outside base CI: 0; direction reversed: 0; largest shift: 0.364 base SE
#> Verdict (interval rule): ROBUST over all counted rows; ROBUST over the 5 sensitivity analyses (same estimand; 0 supplementary rows)
```
