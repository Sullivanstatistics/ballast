# Smallest set of subjects whose removal changes the conclusion

A greedy forward search: at each step every remaining subject is removed
in turn from the current data, the pre-specified model is refitted, and
the subject whose removal moves the result furthest towards the target
is dropped for good. The search stops when the target is reached or
after `max_k` steps. The number of steps needed is a continuous-outcome
analogue of the fragility index; because the search is greedy it is an
upper bound on the true minimum.

## Usage

``` r
stress_fragility(
  spec,
  target = c("significance", "ci", "direction"),
  max_k = 5,
  candidates = NULL,
  cores = 1L
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- target:

  What has to change: `"significance"` (the p-value crosses alpha in
  either direction, depending on the base result), `"ci"` (the estimate
  leaves the base confidence interval) or `"direction"` (the estimate
  changes sign).

- max_k:

  Maximum number of subjects to remove.

- candidates:

  Optional character vector of subject identifiers to restrict the
  search to (one arm, say).

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame with one row per step (`kind = "deletion"`,
`param` = number removed, `label` = the subjects removed so far).
`attr(, "fragility")` is a list with `target`, `k` (the step at which
the target was reached, `NA` if never), `subjects` and `reached`.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
fr <- stress_fragility(spec, max_k = 2)
attr(fr, "fragility")
#> $target
#> [1] "significance"
#> 
#> $k
#> [1] 1
#> 
#> $subjects
#> [1] "PT1"
#> 
#> $reached
#> [1] TRUE
#> 
#> $base_p
#> [1] 0.1099548
#> 
#> $base_estimate
#> [1] 3.478182
#> 
```
