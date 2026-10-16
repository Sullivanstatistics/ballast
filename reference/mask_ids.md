# Mask subject identifiers in a census

Replaces subject identifiers in the labels of the leave-one-subject-out
and deletion-search rows with sequence numbers (`S001`, `S002`, ...) in
the order of the spec's subject levels, so that a census, report or page
can leave the organisation without participant identifiers. The mapping
is returned as `attr(, "id_map")`.

## Usage

``` r
mask_ids(census, spec)
```

## Arguments

- census:

  A `stress_census` (or `stress_rows`).

- spec:

  The
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md)
  the census was built from.

## Value

The same object with masked labels.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:40), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
cen <- stress_census(spec, stress_loo(spec))
head(mask_ids(cen, spec)$label)
#> [1] "S001" "S002" "S003" "S004" "S005" "S006"
```
