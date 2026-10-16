# Perturbation family: intercurrent-event strategies (ICH E9(R1))

Declares the intercurrent events that occurred and derives the analysis
data set implied by each handling strategy, then refits the
pre-specified model on each. Strategies per event type:

## Usage

``` r
stress_estimand(
  spec,
  ice,
  strategies = c("treatment_policy", "hypothetical", "while_on_treatment", "composite"),
  composite_value = NULL,
  cores = 1L
)
```

## Arguments

- spec:

  A
  [`stress_spec()`](https://sullivanstatistics.github.io/ballast/reference/stress_spec.md).

- ice:

  A data frame with one row per intercurrent event: the subject
  identifier (column named as the spec's `subject`), the first visit
  affected (column named as the spec's `visit`) and `type` (a label such
  as `"discontinuation"` or `"rescue"`).

- strategies:

  Named list, one element per event type, each a character vector of
  strategies to apply; or a single character vector applied to every
  type.

- composite_value:

  A number or function used by the composite strategy.

- cores:

  Number of worker processes; `1` fits sequentially.

## Value

A `stress_rows` data frame, one row per strategy combination;
`attr(, "data")` holds the derived data sets by label.

## Details

- `"treatment_policy"`: use the data as observed, whatever happened.

- `"hypothetical"`: set the responses at and after the event to missing;
  the model's missing-at-random assumption then supplies the value the
  subject would have had without the event.

- `"while_on_treatment"`: drop the records at and after the event.

- `"composite"`: replace the responses at and after the event with an
  unfavourable value: a number, or a function `function(data, rows)`
  returning one value per affected row (the worst observed change in the
  subject's arm at that visit, say).

With several event types the strategies are crossed, one row per
combination, and the row that applies `"treatment_policy"` to every type
reproduces the pre-specified data and is flagged `is_base`. Every other
row targets a different estimand, so they are `role = "supplementary"`;
a hypothetical strategy can be followed by
[`stress_reference()`](https://sullivanstatistics.github.io/ballast/reference/stress_reference.md)
on the derived data for its reference-based sensitivity analyses.

## Examples

``` r
small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:80), ]
spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                    covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
ice <- data.frame(USUBJID = c("PT2", "PT5", "PT9"), AVISIT = c("VIS3", "VIS2", "VIS4"),
                  type = c("discontinuation", "discontinuation", "rescue"))
strat <- list(discontinuation = c("treatment_policy", "hypothetical"),
              rescue = c("treatment_policy", "composite"))
stress_estimand(spec, ice, strategies = strat, composite_value = 20)
#>                        family
#> 1 intercurrent-event strategy
#> 2 intercurrent-event strategy
#> 3 intercurrent-event strategy
#> 4 intercurrent-event strategy
#>                                                          label        kind
#> 1 discontinuation: treatment_policy | rescue: treatment_policy alternative
#> 2     discontinuation: hypothetical | rescue: treatment_policy alternative
#> 3        discontinuation: treatment_policy | rescue: composite alternative
#> 4            discontinuation: hypothetical | rescue: composite alternative
#>            role is_base converged     note estimate   stderr       df
#> 1   sensitivity    TRUE      TRUE 3 events 4.483342 1.841041 208.5350
#> 2 supplementary   FALSE      TRUE 3 events 4.269365 1.899072 206.3280
#> 3 supplementary   FALSE      TRUE 3 events 3.364471 1.949706 212.3236
#> 4 supplementary   FALSE      TRUE 3 events 3.131690 2.014102 209.3060
#>          lcl      ucl          p n_subj n_obs     aicc param covariance
#> 1  0.8539049 8.112780 0.01572314     79   225 1475.705    NA         cs
#> 2  0.5252906 8.013440 0.02562527     79   221 1450.770    NA         cs
#> 3 -0.4787884 7.207730 0.08586886     79   225 1503.388    NA         cs
#> 4 -0.8388355 7.102216 0.12148502     79   221 1478.215    NA         cs
#>          method       vcov covariates alpha
#> 1 Satterthwaite Asymptotic    FEV1_BL  0.05
#> 2 Satterthwaite Asymptotic    FEV1_BL  0.05
#> 3 Satterthwaite Asymptotic    FEV1_BL  0.05
#> 4 Satterthwaite Asymptotic    FEV1_BL  0.05
```
