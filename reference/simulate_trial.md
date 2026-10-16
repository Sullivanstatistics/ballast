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
