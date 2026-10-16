# Write the run log for an audit trail

Records the plan text and its MD5 hash, the seed, the package and R
versions, the platform, the elapsed time and the verdict, as JSON if
`jsonlite` is installed and as plain text otherwise. The hash of the
plan text lets a reviewer confirm that the stress test run is the one
that was pre-specified.

## Usage

``` r
stress_log(result, file = NULL, seed = 1)
```

## Arguments

- result:

  A `stress_result`.

- file:

  Path to write; `NULL` returns the log without writing.

- seed:

  The seed that was passed to
  [`run_plan()`](https://sullivanstatistics.github.io/ballast/reference/run_plan.md).

## Value

The log as a list, invisibly.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
plan <- stress_plan(spec, covariance = list(structures = c("cs", "ar1h")), inference = NULL,
                    covariates = NULL, weights = FALSE, loo = NULL, permute = NULL,
                    reference = NULL, estimator = NULL, fragility = NULL)
str(stress_log(run_plan(plan)))
#> List of 15
#>  $ title      : chr "Pre-specified stress test"
#>  $ plan_md5   : chr "1671098149238ded950d00f439f2509a"
#>  $ plan       : chr [1:10] "Pre-specified stress test" "" "Pre-specified analysis: FEV1 ~ FEV1_BL + ARMCD + AVISIT + ARMCD:AVISIT + cs(AVISIT | USUBJID); contrast TRT min"| __truncated__ "" ...
#>  $ run_time   : chr "2026-10-16 22:29:07 UTC"
#>  $ seed       : num 1
#>  $ elapsed_min: num 0
#>  $ r_version  : chr "R version 4.6.1 (2026-06-24)"
#>  $ ballast    : chr "0.4.0"
#>  $ mmrm       : chr "0.3.19"
#>  $ platform   : chr "x86_64-pc-linux-gnu"
#>  $ data       :List of 4
#>   ..$ subjects: int 60
#>   ..$ rows    : int 240
#>   ..$ response: chr "FEV1"
#>   ..$ arms    : chr [1:2] "PBO" "TRT"
#>  $ families   : chr "covariance"
#>  $ rows       : int 2
#>  $ counted    : int 1
#>  $ verdict    :List of 6
#>   ..$ stability            : chr "robust"
#>   ..$ stability_sensitivity: chr "robust"
#>   ..$ marginal             : logi FALSE
#>   ..$ crossed              : int 0
#>   ..$ outside_ci           : int 0
#>   ..$ reversed             : int 0
```
