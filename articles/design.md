# Designing for a robust result

A trial is usually sized so that a true effect of a given size is
significant with probability 0.8 or 0.9. The stress test adds a second
question: with what probability will that significant result also be
**robust**, so that no pre-specified alternative analysis or single
deletion moves it across the significance level, outside the interval or
across zero? Simulation shows the two probabilities differ. At
conventional power 0.8 roughly a third of significant results are
classed sensitive, because a p-value that lands near alpha is what a
correctly sized trial produces much of the time. At power 0.95 the share
falls to about one in six.

[`stress_design()`](https://sullivanstatistics.github.io/ballast/reference/stress_design.md)
makes this a design quantity. It simulates the planned trial over a grid
of sample sizes and effect sizes, runs the light stress test on each
simulated trial and reports the **robustness power**, the probability of
a significant and robust result, next to the conventional power.

``` r

library(ballast)
des <- stress_design(n_per_arm = c(50, 75, 100, 150), delta = c(0, 4.5),
                     n_visits = 4, sigma = 10, rho = 0.6, dropout = 0.03,
                     covariance = "ar1h", method = "Satterthwaite", vcov = "Asymptotic",
                     n_trials = 200, cores = 8)
des
plot(des)
```

The print method names the smallest sample size per arm that reaches a
target robustness power (0.8 by default) for each non-zero effect. The
plot draws both probabilities against the sample size, one panel per
effect size, with the null panel showing the type I error and the share
of false positives that would be flagged.

## What the cells report

For every (sample size, effect) cell the table gives:

- `power` and `robustness_power`: significant, and significant and
  robust.
- `robust_given_sig`, `sensitive_given_sig`, `fragile_given_sig`: the
  verdict rates among significant results. Under the null these describe
  what a false positive looks like to the stress test.
- `marginal_given_sig`: how often the marginal flag would be set.
- `k1_given_sig`: how often removing one subject loses significance.
  With `fragility = TRUE` the greedy deletion search runs instead and
  `k_reached_given_sig` and `k_median` describe the fragility index.
- `tipping_margin` and `tipping_absorbed`, with `tipping = TRUE`: the
  shift applied to imputed active-arm values at which p crosses alpha,
  as a multiple of the effect, and the share of significant trials that
  absorb the whole grid.
- `max_shift_se`: the median, over trials, of the largest shift in
  pre-specified standard errors under the families.

## A small illustration

A fast pass without the deletion family, for the vignette build:

``` r

library(ballast)
des <- stress_design(n_per_arm = c(20, 40), delta = c(0, 6), n_visits = 3, n_trials = 3, loo = FALSE, seed = 2)
des
#> Design stress test: 3 trials per cell, 3 visits, SD 10, AR(1) 0.6, dropout 0.08 per visit; model us / Satterthwaite / Asymptotic; alpha 0.05
#> Families: covariance, inference, covariates, weighting
#>  n_per_arm delta trials power robustness_power robust_given_sig
#>         20     0      3 0.000            0.000               NA
#>         40     0      3 0.000            0.000               NA
#>         20     6      3 0.333            0.000                0
#>         40     6      3 0.667            0.667                1
#>  sensitive_given_sig fragile_given_sig marginal_given_sig k1_given_sig
#>                   NA                NA                 NA           NA
#>                   NA                NA                 NA           NA
#>                    1                 0                  1            0
#>                    0                 0                  0            0
#>  max_shift_se
#>         0.521
#>         0.632
#>         0.379
#>         0.225
#> Effect 6: no sample size in the grid reaches robustness power 0.8 (largest 0.67 at n = 40)
```

Three trials per cell is far too few for a real design; 200 per cell
with the deletion family is a run of minutes to an hour depending on the
sample size, since the deletion family refits once per subject.

## Writing it into the analysis plan

The expected rates belong in the statistical analysis plan next to the
pre-specified stress test.
[`stress_sap()`](https://sullivanstatistics.github.io/ballast/reference/stress_sap.md)
writes the plan text; a sentence such as “under the design assumptions
the probability of a significant and robust result is 0.72 and about one
significant result in four is expected to be classed sensitive” gives
the verdict after unblinding a pre-registered comparison. A sensitive
verdict then reads as the expected consequence of a p-value near alpha
rather than as a discovery, and a fragile verdict for a significant
result, which the simulations put at well under one in a hundred, reads
as the warning it is.

## Assumptions in the simulator

[`simulate_trial()`](https://sullivanstatistics.github.io/ballast/reference/simulate_trial.md)
draws AR(1) errors with a common residual SD, a treatment effect growing
linearly to `delta` at the last visit, a baseline covariate, and dropout
after each visit that depends on the current value. Heavy tails,
heteroscedastic visits, dropout depending on the unobserved next value
and effect modification by baseline are available as settings. The
pre-specified covariance in the analysis need not be the true one; the
covariance family always includes the structures named in
`alternatives`.
