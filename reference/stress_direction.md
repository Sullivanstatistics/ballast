# Direction stability of a result that misses significance

A small trial can carry a real effect and still miss significance for
want of power. For such a result the stress test reports how stable what
was seen is: how many pre-specified re-analyses reverse the direction of
the estimate, and which; how many move it outside the filed confidence
interval; and how many participants the greedy deletion search removes
before the direction reverses.

## Usage

``` r
stress_direction(
  spec,
  census = NULL,
  max_k = 10L,
  method = c("ranked", "greedy"),
  cores = 1L
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- census:

  Optional `stress_census` over the pre-specified re-analyses. If given,
  its counted rows supply the reversal and interval counts; without it
  only the deletion count is computed.

- max_k:

  Most participants to remove in the deletion search
  ([`stress_fragility()`](https://sullivanstatistics.github.io/ballast/reference/stress_fragility.md)
  with `target = "direction"`). The default is 10.

- method:

  `"ranked"` (default) or `"greedy"`, as in
  [`stress_fragility()`](https://sullivanstatistics.github.io/ballast/reference/stress_fragility.md).

- cores:

  Passed to
  [`stress_fragility()`](https://sullivanstatistics.github.io/ballast/reference/stress_fragility.md).

## Value

A list of class `stress_direction`: `base` (the pre-specified fit), `z`,
`n`, `significant`, `alpha`; from the census `n_counted`, `n_reversed`,
`n_outside_ci` and `reversed_rows` (`NA` and `NULL` without one); from
the search `k_rev` (participants removed to reverse, `NA` if not reached
within `max_k`), `k_rev_reached`, `subjects`, `share_of_n` and `search`,
the rows of the search.

## See also

[`stress_verdict()`](https://sullivanstatistics.github.io/ballast/reference/stress_verdict.md)
for the summary label,
[`stress_fragility()`](https://sullivanstatistics.github.io/ballast/reference/stress_fragility.md)
for the deletion searches.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
cen <- stress_census(spec, stress_covariance(spec, c("cs", "ar1h")), stress_covariates(spec))
stress_direction(spec, cen, max_k = 6)
#> Direction stability
#> Base: estimate 3.48, 95% CI -0.796 to 7.75, p = 0.11 (z = 1.61); not significant at alpha 0.05
#> Pre-specified re-analyses: 0 of 2 reverse the direction; 0 move the estimate outside the filed interval
#> Participants removed to reverse the direction (ranked search): 5 of 59 (8%): PT3, PT19, PT43, PT5, PT26
```
