# Perturbation family: re-randomisation (permutation) test

Permutes treatment labels across subjects, optionally within strata,
refits the pre-specified model each time and returns the permutation
p-value for the observed contrast. The returned row carries the observed
estimate and the permutation p; the null distribution is attached as
`attr(, "null")`.

## Usage

``` r
stress_permute(
  spec,
  n = 1000,
  strata = NULL,
  statistic = c("estimate", "t"),
  seed = 1,
  cores = 1L
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- n:

  Number of permutations.

- strata:

  Name of a subject-level column to permute within; `NULL` permutes
  freely.

- statistic:

  `"estimate"` (the contrast; the permutation refits skip the adjusted
  degrees of freedom, so this is the fast choice) or `"t"` (estimate
  over its standard error, refitted with the spec's inference).

- seed:

  Random seed.

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A one-row `stress_rows` data frame with `p` equal to
`(1 + number of |null| >= |observed|) / (n + 1)`.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL)
stress_permute(spec, n = 19)
#>                  family           label        kind        role is_base
#> 1 re-randomisation test 19 permutations alternative sensitivity   FALSE
#>   converged                                                          note
#> 1      TRUE statistic = estimate; 19 of 19 permutations converged; seed 1
#>   estimate   stderr df lcl ucl   p n_subj n_obs aicc param covariance
#> 1 3.597563 3.026508 NA  NA  NA 0.1     59   166   NA    NA         us
#>          method                 vcov covariates alpha
#> 1 Kenward-Roger Kenward-Roger-Linear    FEV1_BL  0.05
```
