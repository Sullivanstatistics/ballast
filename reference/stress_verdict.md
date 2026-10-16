# Classify the census: robust, sensitive or fragile, and marginal

Applies the definitions: *fragile* if any counted row reverses the base
direction or lies outside the base confidence interval; otherwise
*sensitive* if any counted row changes significance at `alpha`;
otherwise *robust*. *Marginal* is a separate flag on the base p-value,
true when it lies within `alpha * marginal_band`.

## Usage

``` r
stress_verdict(census, marginal_band = c(0.5, 2))
```

## Arguments

- census:

  A `stress_census`.

- marginal_band:

  Multiplicative band around `alpha` for the marginal flag; the default
  flags a base p between `alpha / 2` and `2 * alpha`.

## Value

A list of class `stress_verdict`: `stability` over every counted row,
`stability_sensitivity` over the rows that keep the estimand
(`role = "sensitivity"`), `marginal`, the counts behind them, and the
rows that drove the classification.
