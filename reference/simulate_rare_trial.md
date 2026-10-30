# Simulate a small trial with rare-disease features

Draws a two-arm longitudinal trial with the features that make small
trials in rare disease hard to read: few participants, heterogeneous
progression (a mixture of fast and slow progressors with a random
slope), an effect that varies with progression, sites, dropout, and
optionally one planted defect. It is the data generator of the
simulation studies in the methods paper and complements
[`simulate_trial()`](https://sullivanstatistics.github.io/ballast/reference/simulate_trial.md),
which it leaves unchanged.

## Usage

``` r
simulate_rare_trial(
  n_per_arm = 25,
  delta = 0,
  n_visits = 4,
  sigma = 10,
  rho = 0.6,
  dropout = 0.03,
  baseline_beta = 0.5,
  population = c("homogeneous", "mixture", "heavy"),
  fast_frac = 0.35,
  fast_decline = 8,
  slope_sd = 4,
  fast_effect = 1.6,
  t_df = 3,
  n_sites = 8,
  site_sd = 2.5,
  defect = c("none", "outlier", "site", "mnar", "allocation"),
  n_outliers = 1,
  outlier_size = 10,
  mnar_strength = 1.5,
  mnar_dropout = 3 * dropout,
  fast_to_active = 0.25,
  seed = NULL
)
```

## Arguments

- n_per_arm:

  Participants per arm (exactly balanced).

- delta:

  Average treatment effect at the last visit (higher is better).

- n_visits, sigma, rho:

  Visits, residual SD and AR(1) correlation.

- dropout:

  Missing-at-random dropout probability per visit.

- baseline_beta:

  Slope of the response on the baseline.

- population:

  `"homogeneous"`, `"mixture"` or `"heavy"`.

- fast_frac, fast_decline, slope_sd, fast_effect:

  Mixture settings.

- t_df:

  Degrees of freedom of the heavy-tailed errors.

- n_sites, site_sd:

  Number of sites and SD of the site effect on progression.

- defect:

  `"none"`, `"outlier"`, `"site"`, `"mnar"` or `"allocation"`.

- n_outliers, outlier_size:

  Outlier settings (size in units of `sigma`).

- mnar_strength, mnar_dropout:

  Informative-dropout settings.

- fast_to_active:

  Allocation-defect setting: the weight with which a fast progressor is
  drawn into the active arm (slow progressors get `1 - fast_to_active`);
  0.5 is fair allocation.

- seed:

  Random seed; the caller's random-number state is restored. The draws
  use R's default generators whatever the caller's
  [`RNGkind()`](https://rdrr.io/r/base/Random.html), so a seed gives the
  same trial in a plain session and on parallel workers.

## Value

A data frame in long format with one row per observed visit: `id`, `arm`
(`"REF"` or `"ACT"`), `site`, `base`, `fast` (0/1), `visit` (`"V1"`,
...) and `y`.

## Details

The response is a change score at visits 1 to `n_visits`. For
participant *i* at visit *v*, with \\t_v = v / V\\, \$\$y\_{iv} = \beta
(b_i - 50) + (d_i + s_i + u\_{site(i)}) t_v + T_i e_i t_v +
\epsilon\_{iv},\$\$ where \\b_i\\ is the baseline, \\d_i\\ the extra
decline of a fast progressor, \\s_i\\ a random slope, \\u\\ a site
effect, \\T_i\\ the active-arm indicator, \\e_i\\ the participant's
treatment effect and \\\epsilon\\ AR(1) errors with standard deviation
`sigma`.

Populations:

- `"homogeneous"`: no progression heterogeneity; `fast` is recorded but
  is not prognostic, so models with and without it target the same
  effect.

- `"mixture"`: a fraction `fast_frac` of fast progressors lose a further
  `fast_decline` points by the last visit; random slope with SD
  `slope_sd`; the effect is `fast_effect` times larger in fast
  progressors, scaled so that the average effect is `delta`.

- `"heavy"`: as homogeneous with Student-t errors on `t_df` degrees of
  freedom, scaled to the same standard deviation.

Defects (each makes a significant result one that should not be
trusted):

- `"outlier"`: `n_outliers` active-arm participants shifted up by
  `outlier_size` standard deviations at every visit (a data error).

- `"site"`: the treatment effect `delta` applies at site 1 only.

- `"mnar"`: active-arm dropout also depends on the unobserved next
  value, so participants about to decline leave (informative dropout),
  with a baseline dropout rate of `mnar_dropout` per visit.

- `"allocation"`: allocation is not independent of prognosis (for
  example a stratification error or selection at enrolment).
  Participants are drawn into the active arm with weight
  `fast_to_active` for fast progressors and `1 - fast_to_active` for
  slow ones, so with `fast_to_active < 0.5` fast progressors (who
  decline more in the `"mixture"` population) gather in the reference
  arm. An analysis that omits `fast` is then biased in favour of the
  active arm; one that adjusts for it is not.

## See also

[`simulate_trial()`](https://sullivanstatistics.github.io/ballast/reference/simulate_trial.md)
for the simpler generator.

## Examples

``` r
d <- simulate_rare_trial(n_per_arm = 20, delta = 5, population = "mixture", seed = 1)
head(d)
#>      id arm  site     base fast visit         y
#> 1 S0001 REF site7 39.34409    0    V1 18.126327
#> 2 S0001 REF site7 39.34409    0    V2  2.774974
#> 3 S0001 REF site7 39.34409    0    V3 11.429294
#> 4 S0001 REF site7 39.34409    0    V4 -5.396804
#> 5 S0002 ACT site6 34.36218    0    V1  1.571670
#> 6 S0002 ACT site6 34.36218    0    V2  6.179818
spec <- stress_spec(d, "y", "id", "visit", "arm", "REF", covariates = ~ base + fast)
stress_fit(spec)[, c("estimate", "stderr", "p")]
#>   estimate   stderr         p
#> 1 5.239965 4.102245 0.2110184
```
