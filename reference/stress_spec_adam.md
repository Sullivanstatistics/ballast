# Build a stress spec from an ADaM basic data structure

Subsets a CDISC ADaM BDS data set (ADEFF, ADQS and the like) to one
parameter, the analysis-flagged post-baseline records, orders the visits
by their numeric code and builds the spec with the baseline value as a
covariate by default.

## Usage

``` r
stress_spec_adam(
  bds,
  paramcd,
  response = "CHG",
  subject = "USUBJID",
  visit = "AVISIT",
  visitn = "AVISITN",
  treatment = "TRTP",
  reference = NULL,
  active = NULL,
  covariates = ~BASE,
  contrast_visit = NULL,
  analysis_flag = "ANL01FL",
  drop_baseline = TRUE,
  filter = NULL,
  covariance = "us",
  method = "Kenward-Roger",
  vcov = "Kenward-Roger-Linear",
  alpha = 0.05,
  weights = "equal",
  label = paste(paramcd, response)
)
```

## Arguments

- bds:

  A BDS data frame.

- paramcd:

  The `PARAMCD` value to analyse.

- response:

  Response column, usually `"CHG"` or `"PCHG"`.

- subject, visit, visitn, treatment:

  Column names (`USUBJID`, `AVISIT`, `AVISITN`, `TRTP` by default).

- reference, active, contrast_visit, covariance, method, vcov, alpha,
  weights, label:

  As in
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- covariates:

  Covariates; the default is the baseline value `BASE`.

- analysis_flag:

  Name of a flag column kept where equal to `"Y"`; `NULL` keeps all
  records.

- drop_baseline:

  Drop records flagged `ABLFL == "Y"` or with a non-positive `visitn`.

- filter:

  Optional function of the data returning the rows to keep, applied
  after the other subsets (an analysis-phase restriction, say).

## Value

A `stress_spec`.

## Examples

``` r
bds <- transform(mmrm::fev_data, PARAMCD = "FEV1", CHG = FEV1 - FEV1_BL, BASE = FEV1_BL,
                 AVISITN = VISITN, TRTP = ARMCD, ANL01FL = "Y")
stress_spec_adam(bds, "FEV1", response = "CHG", visit = "AVISIT", reference = "PBO")
#> <stress_spec> FEV1 CHG
#>   data:       800 rows, 200 subjects, visits VIS1 VIS2 VIS3 VIS4
#>   model:      CHG ~ BASE + TRTP + AVISIT + TRTP:AVISIT + us(AVISIT | USUBJID)
#>   contrast:   TRT - PBO at VIS4
#>   inference:  Kenward-Roger df, Kenward-Roger-Linear vcov, alpha 0.05
```
