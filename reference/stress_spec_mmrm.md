# Build a stress spec from a fitted mmrm model

Takes the data, response, subject, visit, covariance structure,
degrees-of-freedom method and variance estimator from an `mmrm` fit. The
treatment variable is the factor that interacts with the visit variable
unless given.

## Usage

``` r
stress_spec_mmrm(
  fit,
  treatment = NULL,
  reference = NULL,
  active = NULL,
  contrast_visit = NULL,
  alpha = 0.05,
  weights = "equal",
  label = "pre-specified",
  sas_conventions = TRUE
)
```

## Arguments

- fit:

  An object of class `mmrm`.

- treatment:

  Name of the treatment column; `NULL` finds the factor in an
  interaction with the visit variable.

- reference, active, contrast_visit, alpha, weights, label,
  sas_conventions:

  As in
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

## Value

A `stress_spec`.

## Examples

``` r
fit <- mmrm::mmrm(FEV1 ~ RACE + SEX + FEV1_BL + ARMCD * AVISIT + us(AVISIT | USUBJID),
                  data = mmrm::fev_data)
stress_spec_mmrm(fit, reference = "PBO")
#> <stress_spec> pre-specified
#>   data:       800 rows, 200 subjects, visits VIS1 VIS2 VIS3 VIS4
#>   model:      FEV1 ~ RACE + SEX + FEV1_BL + ARMCD + AVISIT + ARMCD:AVISIT + us(AVISIT | USUBJID)
#>   contrast:   TRT - PBO at VIS4
#>   inference:  Satterthwaite df, Asymptotic vcov, alpha 0.05
```
