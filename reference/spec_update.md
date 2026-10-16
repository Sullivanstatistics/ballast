# Modify a stress spec

Returns a copy of `spec` with the named settings replaced. Settings that
change the data conventions (`reference`, `visit`, `treatment`,
`subject`, `response`) cannot be changed here; build a new spec instead.

## Usage

``` r
spec_update(spec, ...)
```

## Arguments

- spec:

  A `stress_spec`.

- ...:

  Settings to replace: `covariance`, `method`, `vcov`, `covariates`,
  `contrast_visit`, `alpha`, `label`, `data`, `weights`, `active`.

## Value

The modified `stress_spec`.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL)
spec_update(spec, covariance = "ar1h", method = "Satterthwaite", vcov = "Asymptotic")
#> <stress_spec> pre-specified
#>   data:       800 rows, 200 subjects, visits VIS1 VIS2 VIS3 VIS4
#>   model:      FEV1 ~ RACE + SEX + FEV1_BL + ARMCD + AVISIT + ARMCD:AVISIT + ar1h(AVISIT | USUBJID)
#>   contrast:   TRT - PBO at VIS4
#>   inference:  Satterthwaite df, Asymptotic vcov, alpha 0.05
```
