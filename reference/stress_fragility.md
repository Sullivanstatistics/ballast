# Smallest set of subjects whose removal changes the conclusion

Two searches for the fewest subjects whose removal moves the result to
the target. The number needed is a continuous-outcome analogue of the
fragility index; both searches give an upper bound on the true minimum.

## Usage

``` r
stress_fragility(
  spec,
  target = c("significance", "ci", "direction"),
  max_k = 5,
  candidates = NULL,
  cores = 1L,
  method = c("greedy", "ranked")
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

- method:

  `"greedy"` or `"ranked"`.

## Value

A `stress_rows` data frame with one row per step (`kind = "search"`, so
the rows are not counted in a census, since the search crosses the
target by construction; `param` = number removed, `label` = the subjects
removed so far). `attr(, "fragility")` is a list with `target`,
`method`, `k` (the step at which the target was reached, `NA` if never),
`subjects` and `reached`.

## Details

- `method = "greedy"` (default): at each step every remaining subject is
  removed in turn from the current data, the pre-specified model is
  refitted, and the subject whose removal moves the result furthest
  towards the target is dropped for good. About `k * n` refits.

- `method = "ranked"`: subjects are ranked once, by how far removing
  each alone moves the result towards the target (the leave-one-out
  refits), and the top 1, 2, ..., k are removed together, one refit per
  step. About refits, so it is practical for large trials. influences at
  once.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
fr <- stress_fragility(spec, max_k = 1)
attr(fr, "fragility")
#> $target
#> [1] "significance"
#> 
#> $method
#> [1] "greedy"
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
attr(stress_fragility(spec, "ci", max_k = 10, method = "ranked"), "fragility")$k
#> [1] 7
```
