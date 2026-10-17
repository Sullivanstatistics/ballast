# Plot power and robustness power against the sample size

Plot power and robustness power against the sample size

## Usage

``` r
# S3 method for class 'stress_design'
plot(x, target = 0.8, ...)
```

## Arguments

- x:

  A `stress_design` object from
  [`stress_design()`](https://sullivanstatistics.github.io/ballast/reference/stress_design.md).

- target:

  Reference line for the robustness power.

- ...:

  Ignored.

## Value

A ggplot: the probability of a significant result and of a significant
and robust result against subjects per arm, one panel per effect size.
