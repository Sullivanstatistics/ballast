# Perturbation family: rank tests at the contrast visit

Model-free tests of the treatment difference in the response at the
contrast visit: the Wilcoxon rank-sum test (normal approximation with
the tie correction and continuity correction, as SAS `PROC NPAR1WAY`
reports it) and, if `strata` is given, the van Elteren test (the
Cochran-Mantel- Haenszel row-mean-score statistic on modified ridit
scores within strata). The rows carry a p-value and the Hodges-Lehmann
shift as the estimate, with no standard error or interval; they count
towards significance only.

## Usage

``` r
stress_ranktest(spec, strata = NULL, cores = 1L)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- strata:

  Name of a subject-level stratification column for the van Elteren
  test; `NULL` runs the Wilcoxon test only.

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame with one or two rows.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
stress_ranktest(spec, strata = "RACE")
#>      family                          label        kind        role is_base
#> 1 rank test              Wilcoxon rank sum alternative sensitivity   FALSE
#> 2 rank test van Elteren stratified by RACE alternative sensitivity   FALSE
#>   converged
#> 1      TRUE
#> 2      TRUE
#>                                                                                                     note
#> 1 normal approximation with tie and continuity correction; estimate = Hodges-Lehmann shift; n = 67 vs 67
#> 2                                   CMH row-mean-score statistic on modified ridit scores, strata = RACE
#>   estimate stderr df lcl ucl           p n_subj n_obs aicc param covariance
#> 1  4.88842     NA NA  NA  NA 0.008430281    134   134   NA    NA         us
#> 2  4.88842     NA NA  NA  NA 0.143793534    134   134   NA    NA         us
#>   method vcov covariates alpha
#> 1 Normal none             0.05
#> 2 Normal none             0.05
```
