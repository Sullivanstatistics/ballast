# Interactive HTML report

Writes an HTML page (its JavaScript dependencies in a `lib` folder
beside it) with the verdict, the summary table and two interactive
figures built with `plotly`: the bubble swarm, where hovering a bubble
lists the specifications that give that estimate, and the deletion
strip, where hovering a dot names the subject removed and shows the
refit's estimate and p-value. Needs `plotly` and `htmlwidgets`.

## Usage

``` r
stress_html(result, file, digits = 2, mask_ids = TRUE)
```

## Arguments

- result:

  A `stress_result` from
  [`run_plan()`](https://sullivanstatistics.github.io/ballast/reference/run_plan.md).

- file:

  Path of the HTML file to write. There is no default, so nothing is
  written unless a path is given.

- digits:

  Rounding used to group estimates into bubbles.

- mask_ids:

  Replace subject identifiers with sequence numbers (on by default: the
  page is the deliverable most likely to leave the organisation).

## Value

The file path, invisibly.

## Examples

``` r
# \donttest{
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
plan <- stress_plan(spec, covariance = list(structures = c("cs", "ar1h")), inference = NULL,
                    covariates = NULL, weights = FALSE, loo = list(by = "RACE"), permute = NULL,
                    reference = NULL, estimator = NULL, fragility = NULL)
if (requireNamespace("plotly", quietly = TRUE) && requireNamespace("htmlwidgets", quietly = TRUE))
  stress_html(run_plan(plan), file.path(tempdir(), "stress.html"))
# }
```
