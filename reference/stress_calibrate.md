# Pre-trial calibration of the stress test

Simulates trials from a planned design and runs a light stress test on
each (covariance, inference, covariate, weighting and leave-one-out
families, plus the greedy deletion search if `fragility = TRUE`), so
that a sponsor can see, before unblinding, how often a trial of this
design would be classed robust, sensitive or fragile at each power, and
how often the marginal flag would be set.

## Usage

``` r
stress_calibrate(
  n_per_arm = 50,
  power = c(0, 0.5, 0.8, 0.95),
  n_trials = 100,
  n_visits = 4,
  sigma = 10,
  rho = 0.6,
  dropout = 0.08,
  baseline_beta = 0.5,
  errors = "normal",
  t_df = 3,
  hetero = 1,
  mnar = 0,
  interaction = 0,
  fragility = FALSE,
  cores = 1L,
  seed = 1
)
```

## Arguments

- n_per_arm:

  Subjects per arm.

- power:

  Target powers for the pre-specified analysis; the effect size giving
  each is derived from the design (0 gives the null).

- n_trials:

  Trials per power.

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

- errors, t_df, hetero, mnar, interaction:

  Misspecification settings passed to
  [`simulate_trial()`](https://sullivanstatistics.github.io/ballast/reference/simulate_trial.md).

- fragility:

  Run the deletion search (slower).

- cores:

  Worker processes (the trials are distributed, so each trial's families
  run on one core).

- seed:

  Base seed.

## Value

A data frame of class `stress_calibration` with one row per power: the
effect size, observed power, and the proportion of trials with each
verdict, the marginal flag, and (if run) a one-subject fragility;
`attr(, "trials")` holds the per-trial rows.

## Examples

``` r
stress_calibrate(n_per_arm = 20, power = c(0, 0.8), n_trials = 2)
#> Stress-test calibration: 20 per arm, 4 visits, SD 10, AR(1) 0.6, dropout 0.08 per visit
#>  power_target delta trials power_observed marginal robust sensitive fragile
#>           0.0  0.00      2            0.0        0      0         0       1
#>           0.8  8.98      2            0.5        0      1         0       0
#>  sensitive_given_sig fragile_k1_given_sig
#>                   NA                   NA
#>                    0                   NA
```
