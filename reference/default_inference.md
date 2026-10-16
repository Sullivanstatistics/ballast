# Default inference settings for [`stress_inference()`](https://sullivanstatistics.github.io/ballast/reference/stress_inference.md)

Default inference settings for
[`stress_inference()`](https://sullivanstatistics.github.io/ballast/reference/stress_inference.md)

## Usage

``` r
default_inference()
```

## Value

A named list of `list(method = , vcov = )` pairs: Satterthwaite,
Kenward-Roger, linear Kenward-Roger (the SAS `DDFM=KR` default),
residual, sandwich with between-within degrees of freedom (SAS
`EMPIRICAL`) and the jackknife sandwich.

## Examples

``` r
names(default_inference())
#> [1] "Satterthwaite"                      "Kenward-Roger"                     
#> [3] "Kenward-Roger (linear)"             "Residual"                          
#> [5] "Sandwich, between-within"           "Jackknife sandwich, between-within"
```
