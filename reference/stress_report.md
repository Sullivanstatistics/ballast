# Write a stress-test report

Writes a Markdown report with the plan, the base analysis, the
per-family summary table, the verdict and the standard figures (census
dot plot, bubble swarm, deletion p-value strip, p-value curves where the
result has rows with a parameter) as PNG files beside it.

## Usage

``` r
stress_report(
  result,
  dir = ".",
  name = "stress_report",
  width = 9,
  height = 5,
  dpi = 150,
  mask_ids = FALSE
)
```

## Arguments

- result:

  A `stress_result` from
  [`run_plan()`](https://sullivanstatistics.github.io/ballast/reference/run_plan.md).

- dir:

  Directory to write into (created if needed).

- name:

  File stem for the report and figures.

- width, height, dpi:

  Figure size in inches and resolution.

- mask_ids:

  Replace subject identifiers with sequence numbers.

## Value

The path of the Markdown file, invisibly.

## Examples

``` r
# \donttest{
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
plan <- stress_plan(spec, covariance = list(structures = c("cs", "ar1h")), inference = NULL,
                    covariates = NULL, weights = FALSE, loo = list(by = "RACE"), permute = NULL,
                    reference = NULL, estimator = NULL, fragility = NULL)
stress_report(run_plan(plan), dir = tempdir())
# }
```
