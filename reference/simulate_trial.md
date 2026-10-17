# Simulate a two-arm longitudinal trial

Multivariate-normal responses at `n_visits` post-baseline visits with an
AR(1) correlation, a baseline covariate, a treatment effect growing
linearly to `delta` at the last visit, and dropout after each visit
whose probability rises as the current value falls (missing at random).

## Usage

``` r
simulate_trial(
  n_per_arm = 50,
  delta = 0,
  n_visits = 4,
  sigma = 10,
  rho = 0.6,
  dropout = 0.08,
  baseline_beta = 0.5,
  errors = c("normal", "t"),
  t_df = 3,
  hetero = 1,
  mnar = 0,
  interaction = 0,
  seed = NULL
)
```

## Arguments

- n_per_arm:

  Subjects per arm.

- delta:

  Treatment effect at the last visit (active minus reference).

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

- seed:

  Random seed.

## Value

A long data frame with `id`, `arm` (`"REF"`, `"ACT"`), `base`, `visit`
(`"V1"`, ...) and `y`, missing rows removed.

## Examples

``` r
d <- simulate_trial(40, delta = 3, seed = 1); head(d)
#>      id arm     base visit          y
#> 1 S0001 REF 43.73546    V1 -8.8189564
#> 2 S0001 REF 43.73546    V2 -3.1434784
#> 3 S0001 REF 43.73546    V3  2.5194907
#> 4 S0001 REF 43.73546    V4 10.7219989
#> 5 S0002 REF 51.83643    V1 -0.4335695
#> 9 S0003 REF 41.64371    V1  7.6027269
```
