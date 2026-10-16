# Run several plans (several endpoints or comparisons) and compare

Run several plans (several endpoints or comparisons) and compare

## Usage

``` r
run_plans(plans, cores = 1L, seed = 1)
```

## Arguments

- plans:

  A named list of `stress_plan` objects.

- cores, seed:

  Passed to
  [`run_plan()`](https://sullivanstatistics.github.io/ballast/reference/run_plan.md).

## Value

A named list of `stress_result` objects of class `stress_results`;
[`summary()`](https://rdrr.io/r/base/summary.html) gives one line per
plan and
[`plot_swarm()`](https://sullivanstatistics.github.io/ballast/reference/plot_swarm.md)
accepts the censuses (`lapply(results, function(r) r$census)`).

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
mk <- function(s) stress_plan(s, covariance = list(structures = c("cs", "ar1h")), inference = NULL,
                              covariates = NULL, weights = FALSE, loo = NULL, permute = NULL,
                              reference = NULL, estimator = NULL, fragility = NULL)
res <- run_plans(list(VIS4 = mk(spec), VIS3 = mk(spec_update(spec, contrast_visit = "VIS3"))))
summary(res)
#>   plan estimate        lcl      ucl         p counted crossed outside_ci
#> 1 VIS4 3.478182 -0.7957403 7.752105 0.1099548       1       0          0
#> 2 VIS3 3.385430 -0.7616274 7.532488 0.1088592       1       1          0
#>   reversed stability stability_sensitivity marginal
#> 1        0    robust                robust    FALSE
#> 2        0 sensitive             sensitive    FALSE
```
