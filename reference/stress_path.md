# Smallest combination of analytic changes that leaves the confidence interval

A greedy search for the fewest analytic changes, made together, that
move the estimate outside the pre-specified 95% confidence interval. At
each step every change from a family not yet used is tried on top of the
changes already made, and the one that moves the estimate furthest in
the search direction is kept. The search stops when the estimate leaves
the interval or `max_j` changes have been made. It runs towards zero
(the direction that weakens the result) and, with `direction = "both"`,
also away from zero; `j` is the smaller count.

## Usage

``` r
stress_path(
  spec,
  changes = path_changes(spec),
  max_j = 3,
  direction = c("both", "toward_zero", "away_from_zero"),
  seed = 1,
  cores = 1L
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md):
  the pre-specified analysis.

- changes:

  Candidate changes from
  [`path_changes()`](https://sullivanstatistics.github.io/ballast/reference/path_changes.md).

- max_j:

  Largest number of changes to combine.

- direction:

  `"both"`, `"toward_zero"` or `"away_from_zero"`.

- seed:

  Seed for the reference-based imputations.

- cores:

  Worker processes (or a cluster) for the candidates of a step.

## Value

A `stress_rows` data frame with one row per step of each direction
searched (`family` is `"analytic path"`), with attribute `"path"`: a
list with `j` (`NA` if not reached within `max_j`), `reached`,
`direction`, `changes` (the labels of the path that reached the boundary
first), `assumption_dependent` and the base estimate and interval.

## Details

Changes combine: a reference-based or delta-adjusted imputation chosen
at one step is kept, and later changes are evaluated under it. A path
that leaves the interval through either is flagged
`assumption_dependent`, so that the reader can see the path ran through
a missing-data assumption rather than through the observed data alone.

Because the search is greedy, `j` is an upper bound on the smallest
combination; to first order the shifts of different families add, so the
greedy path is the worst case when they do.

The search is exact but avoids repeated work: the imputation draws are
made once per imputation model and reused by every change that leaves
the model alone, a state reached twice (by both directions, or by two
orders of the same changes) is fitted once, and the second direction is
searched only as far as it could still give a shorter path than the
first.

## See also

[`stress_fragility()`](https://sullivanstatistics.github.io/ballast/reference/stress_fragility.md)
for the deletion searches.

## Examples

``` r
# \donttest{
d <- simulate_rare_trial(25, delta = 6, population = "mixture", seed = 2)
spec <- stress_spec(d, "y", "id", "visit", "arm", "REF", covariates = ~ base + fast,
                    method = "Satterthwaite", vcov = "Asymptotic")
p <- stress_path(spec, path_changes(spec, reference = "J2R", m = 5), max_j = 3)
attr(p, "path")$j
#> [1] NA
# }
```
