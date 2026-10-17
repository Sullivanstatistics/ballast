# Define the pre-specified MMRM to stress-test

A `stress_spec` holds the analysis data and every decision of the
pre-specified mixed model for repeated measures: the response, subject,
visit and treatment variables, the covariates, the visit at which the
treatment contrast is taken, the within-subject covariance structure,
the degrees-of-freedom method, the variance estimator and the
significance level. Every family function in the package takes a spec
and returns rows in the schema of
[`stress_fit()`](https://sullivanstatistics.github.io/ballast/reference/stress_fit.md).

## Usage

``` r
stress_spec(
  data,
  response,
  subject,
  visit,
  treatment,
  reference = NULL,
  active = NULL,
  covariates = NULL,
  contrast_visit = NULL,
  covariance = "us",
  method = "Kenward-Roger",
  vcov = "Kenward-Roger-Linear",
  alpha = 0.05,
  weights = c("equal", "observed"),
  label = "pre-specified",
  sas_conventions = TRUE,
  time = NULL
)
```

## Arguments

- data:

  A data frame in long format, one row per subject and visit.

- response:

  Name of the response column (change from baseline, say).

- subject:

  Name of the subject identifier column.

- visit:

  Name of the visit column; coerced to a factor whose level order is the
  visit order.

- treatment:

  Name of the treatment column (two or more arms).

- reference:

  The reference (control) level of `treatment`. Defaults to the first
  factor level.

- active:

  The treatment level compared with the reference. Defaults to the first
  non-reference level. With three or more arms, change it with
  [`spec_update()`](https://sullivanstatistics.github.io/ballast/reference/spec_update.md)
  to stress-test each comparison in turn.

- covariates:

  Fixed-effect covariates besides treatment and visit, as a one-sided
  formula (`~ base + site`) or a character vector of term labels.
  Character and logical columns are treated as class variables.

- contrast_visit:

  The visit level at which the treatment contrast is estimated. Defaults
  to the last visit level.

- covariance:

  Covariance structure name as used by `mmrm`: `"us"`, `"ar1"`,
  `"ar1h"`, `"cs"`, `"csh"`, `"toep"`, `"toeph"`, `"ad"`, `"adh"`, or
  `"sp_exp"` (spatial exponential, the SAS `SP(POW)` structure, on the
  continuous `time` variable).

- method:

  Degrees-of-freedom method passed to
  [`mmrm::mmrm_control()`](https://openpharma.github.io/mmrm/latest-tag/reference/mmrm_control.html):
  `"Satterthwaite"`, `"Kenward-Roger"`, `"Residual"` or
  `"Between-Within"`.

- vcov:

  Variance estimator passed to
  [`mmrm::mmrm_control()`](https://openpharma.github.io/mmrm/latest-tag/reference/mmrm_control.html):
  `"Asymptotic"`, `"Empirical"`, `"Empirical-Jackknife"`,
  `"Empirical-Bias-Reduced"`, `"Kenward-Roger"` or
  `"Kenward-Roger-Linear"`. The SAS `DDFM=KR` default corresponds to
  `method = "Kenward-Roger"` with `vcov = "Kenward-Roger-Linear"`.

- alpha:

  Two-sided significance level.

- weights:

  How class covariates are weighted in the least-squares means:
  `"equal"` (every level equally, SAS `LSMEANS` default) or `"observed"`
  (the design is averaged over the covariate values of the analysis
  rows, as SAS `OBSMARGINS` and g-computation do).

- label:

  Label for the base analysis in output rows.

- sas_conventions:

  If `TRUE`, the between-within degrees of freedom for a
  sandwich-variance contrast are computed as SAS `PROC MIXED` does when
  `EMPIRICAL` is combined with a `DDFM` it cannot honour (observations
  minus subjects minus the rank of the within-subject design columns).

- time:

  Name of a numeric time column for the `"sp_exp"` structure (days from
  randomisation, say; mmrm converges more readily with time rescaled to
  hundreds of days).

## Value

An object of class `stress_spec`.

## Details

The fixed effects are
`covariates + treatment + visit + treatment:visit`; the treatment
contrast at `contrast_visit` is the difference of least-squares means
(active minus reference) with class covariates weighted equally over
their levels and continuous covariates at their means, the convention of
SAS `LSMEANS`.

## Examples

``` r
spec <- stress_spec(mmrm::fev_data, response = "FEV1", subject = "USUBJID",
                    visit = "AVISIT", treatment = "ARMCD", reference = "PBO",
                    covariates = ~ RACE + SEX + FEV1_BL, contrast_visit = "VIS4")
spec
#> <stress_spec> pre-specified
#>   data:       800 rows, 200 subjects, visits VIS1 VIS2 VIS3 VIS4
#>   model:      FEV1 ~ RACE + SEX + FEV1_BL + ARMCD + AVISIT + ARMCD:AVISIT + us(AVISIT | USUBJID)
#>   contrast:   TRT - PBO at VIS4
#>   inference:  Kenward-Roger df, Kenward-Roger-Linear vcov, alpha 0.05
```
