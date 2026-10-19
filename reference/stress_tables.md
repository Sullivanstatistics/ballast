# Write regulatory-style tables and the census

Writes the per-family summary, the rows that crossed alpha or left the
interval, the deletion-search path and the full census. CSV files are
always written; with `flextable` and `officer` installed, a Word
document with the tables in a standard clinical-report layout is written
too, and an RTF version of each table.

## Usage

``` r
stress_tables(
  result,
  dir,
  name = "stress",
  formats = c("csv", "docx", "rtf"),
  digits = 3,
  mask_ids = FALSE
)
```

## Arguments

- result:

  A `stress_result` from
  [`run_plan()`](https://sullivanstatistics.github.io/ballast/reference/run_plan.md).

- dir:

  Directory to write into (created if needed). There is no default, so
  nothing is written unless a location is given.

- name:

  File stem.

- formats:

  Any of `"csv"`, `"docx"`, `"rtf"`.

- digits:

  Decimal places in the formatted tables.

- mask_ids:

  Replace subject identifiers with sequence numbers.

## Value

The paths written, invisibly.

## Examples

``` r
# \donttest{
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
plan <- stress_plan(spec, covariance = list(structures = c("cs", "ar1h")), inference = NULL,
                    covariates = NULL, weights = FALSE, loo = list(by = "RACE"), permute = NULL,
                    reference = NULL, estimator = NULL, fragility = NULL)
stress_tables(run_plan(plan), dir = tempdir(), formats = "csv")
# }
```
