# Find where a p-value curve crosses alpha

For rows that carry a `param` value (from
[`stress_tipping()`](https://sullivanstatistics.github.io/ballast/reference/stress_tipping.md)
or
[`stress_curve()`](https://sullivanstatistics.github.io/ballast/reference/stress_curve.md)),
interpolates linearly between adjacent parameter values to find where
the p-value crosses `alpha`, separately for each family.

## Usage

``` r
tipping_point(rows, alpha = NULL)
```

## Arguments

- rows:

  A `stress_rows` data frame or a `stress_census`.

- alpha:

  Significance level; defaults to the rows' own `alpha`.

## Value

A data frame with one row per family: `family`, `n` points, `param_min`,
`param_max`, `p_min`, `p_max`, `crossing` (the interpolated parameter
value, `NA` when the curve does not cross) and `direction` (`"up"` when
p rises through alpha with increasing parameter, `"down"` otherwise).
