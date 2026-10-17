# Size a trial for a robust result

Simulates trials from a planned design over a grid of sample sizes and
effect sizes, runs the light stress test on each (covariance, inference,
covariate, weighting and leave-one-subject-out families) and reports,
for every cell, the conventional power next to the robustness power: the
probability that the pre-specified analysis is significant and classed
robust. The deletion search and a delta-adjusted tipping grid are
optional and give the expected fragility index and the shift the result
can absorb. This is the design-stage use of the stress test: choose the
sample size so that a true effect is expected to come out robust rather
than only significant, and write the expected verdict rates into the
statistical analysis plan before unblinding so that the observed verdict
has a pre-registered comparison.

## Usage

``` r
stress_design(
  n_per_arm,
  delta,
  n_trials = 100,
  n_visits = 4,
  sigma = 10,
  rho = 0.6,
  dropout = 0.08,
  baseline_beta = 0.5,
  covariance = "us",
  method = "Satterthwaite",
  vcov = "Asymptotic",
  alpha = 0.05,
  alternatives = c("us", "ar1h", "cs"),
  loo = TRUE,
  fragility = FALSE,
  max_k = 5,
  tipping = FALSE,
  shifts = seq(0, 2, by = 0.25),
  m = 5,
  errors = "normal",
  t_df = 3,
  hetero = 1,
  mnar = 0,
  interaction = 0,
  cores = 1L,
  seed = 1
)

# S3 method for class 'stress_design'
print(x, target = 0.8, ...)
```

## Arguments

- n_per_arm:

  Subjects per arm to evaluate (a vector).

- delta:

  Treatment effects at the last visit to evaluate (a vector); include 0
  to see the null.

- n_trials:

  Trials per cell.

- n_visits:

  Number of post-baseline visits.

- sigma:

  Residual standard deviation at each visit.

- rho:

  AR(1) correlation between adjacent visits.

- dropout:

  Baseline per-visit dropout probability.

- baseline_beta:

  Slope of the response on the baseline covariate.

- covariance, method, vcov:

  The pre-specified analysis model, as in
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- alpha:

  Two-sided significance level.

- alternatives:

  Covariance structures offered as alternatives; the pre-specified one
  is removed from the set.

- loo:

  Run the leave-one-subject-out family.

- fragility:

  Run the greedy deletion search for significance up to `max_k` removals
  (slow). Otherwise a one-subject loss of significance is read from the
  leave-one-out rows.

- max_k:

  Removals allowed in the deletion search.

- tipping:

  Run a delta-adjusted tipping grid (imputed active-arm values shifted
  down) and record the shift at which `p` crosses `alpha`.

- shifts:

  Shifts for the tipping grid as multiples of `delta` (of `sigma` when
  `delta` is 0).

- m:

  Imputations per shift.

- errors:

  `"normal"` or `"t"` (Student t with `t_df` degrees of freedom, scaled
  to the same standard deviation: heavy tails).

- t_df:

  Degrees of freedom for `errors = "t"`.

- hetero:

  Multiplier of the residual standard deviation at the last visit
  relative to the first (1 = homoscedastic); the SD grows linearly.

- mnar:

  Strength of missing-not-at-random dropout: dropout after a visit
  depends on the value the subject would have had at the NEXT visit (0 =
  missing at random, as the default).

- interaction:

  Treatment effect modification by the baseline covariate: the effect at
  the last visit is `delta * (1 + interaction * (base - 50) / 10)`.

- cores:

  Worker processes. Trials are distributed, so each trial's families run
  on one core.

- seed:

  Base seed; every trial's seed is derived from it.

- x:

  A `stress_design` object.

- target:

  Robustness power to reach; the print method names the smallest sample
  size per arm that reaches it for each non-zero effect.

- ...:

  Ignored.

## Value

A data frame of class `stress_design` with one row per cell:
`n_per_arm`, `delta`, `trials`, `power` (proportion significant),
`robustness_power` (significant and robust), `robust_given_sig`,
`sensitive_given_sig`, `fragile_given_sig`, `marginal_given_sig`,
`k1_given_sig` (one deletion loses significance), `k_reached_given_sig`
and `k_median` (deletion search, if run), `tipping_margin` (median shift
that crosses `alpha` among significant trials, as a multiple of `delta`
or `sigma`) and `tipping_absorbed` (share of significant trials with no
crossing within the grid), and `max_shift_se` (median largest shift in
pre-specified standard errors). `attr(, "trials")` holds the per-trial
rows and `attr(, "design")` the settings.
[`plot.stress_design()`](https://sullivanstatistics.github.io/ballast/reference/plot.stress_design.md)
draws power and robustness power against the sample size.

## Details

The light family set offers the alternative covariance structures, three
inference methods, the model without the baseline covariate,
observed-margin weighting and, if `loo = TRUE`, every single-subject
deletion. Deletions dominate the run time at large sample sizes;
`loo = FALSE` gives a fast first pass whose verdicts omit the deletion
family.

## See also

[`stress_calibrate()`](https://sullivanstatistics.github.io/ballast/reference/stress_calibrate.md)
for the verdict rates of one design at a set of planned powers;
[`stress_sap()`](https://sullivanstatistics.github.io/ballast/reference/stress_sap.md)
for the analysis-plan text.

## Examples

``` r
# \donttest{
des <- stress_design(n_per_arm = c(40, 80), delta = c(0, 5), n_trials = 4, loo = FALSE)
des
#> Design stress test: 4 trials per cell, 4 visits, SD 10, AR(1) 0.6, dropout 0.08 per visit; model us / Satterthwaite / Asymptotic; alpha 0.05
#> Families: covariance, inference, covariates, weighting
#>  n_per_arm delta trials power robustness_power robust_given_sig
#>         40     0      4  0.00             0.00               NA
#>         80     0      4  0.00             0.00               NA
#>         40     5      4  0.25             0.25             1.00
#>         80     5      4  1.00             0.75             0.75
#>  sensitive_given_sig fragile_given_sig marginal_given_sig k1_given_sig
#>                   NA                NA                 NA           NA
#>                   NA                NA                 NA           NA
#>                 0.00                 0                  0            0
#>                 0.25                 0                  0            0
#>  max_shift_se
#>         0.467
#>         0.343
#>         0.231
#>         0.539
#> Effect 5: no sample size in the grid reaches robustness power 0.8 (largest 0.75 at n = 80)
# }
```
