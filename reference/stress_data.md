# Perturbation family: alternative analysis data sets

The generic data-decision family. Each alternative is a data frame in
the spec's layout (an intercurrent-event handling, a different baseline
definition, a contested record reversed, a different visit window). The
pre-specified model is refitted on each.

## Usage

``` r
stress_data(
  spec,
  alternatives,
  family = "data handling",
  role = "supplementary",
  cores = 1L
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- alternatives:

  Named list of data frames.

- family:

  Family label for the rows.

- role:

  `"supplementary"` (the default: an alternative data set usually
  targets a different estimand) or `"sensitivity"`.

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame, one row per alternative.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
alt <- mmrm::fev_data
alt$FEV1[alt$USUBJID == "PT1"] <- NA   # one subject's records set missing
stress_data(spec, list("PT1 removed" = alt))
#>          family       label        kind          role is_base converged note
#> 1 data handling PT1 removed alternative supplementary   FALSE      TRUE     
#>   estimate   stderr       df      lcl     ucl           p n_subj n_obs     aicc
#> 1 4.854738 1.624677 132.2215 1.641016 8.06846 0.003347088    196   535 3360.377
#>   param covariance        method                 vcov           covariates
#> 1    NA         us Kenward-Roger Kenward-Roger-Linear RACE + SEX + FEV1_BL
#>   alpha
#> 1  0.05
```
