# Summarise a census by family

Summarise a census by family

## Usage

``` r
# S3 method for class 'stress_census'
summary(object, ...)
```

## Arguments

- object:

  A `stress_census`.

- ...:

  Unused.

## Value

A data frame with one row per family, kind and role: counted analyses,
number significant, number that crossed `alpha`, number outside the base
confidence interval, number reversing direction, the range of percent of
base, the largest shift in base standard errors, and `counted`.
Diagnostic refits (`kind = "diagnostic"`) get their own line with
`counted = FALSE` so a reader sees they were fitted; they are left out
of the closing rows, which total the sensitivity analyses (same
estimand) and all counted rows.
