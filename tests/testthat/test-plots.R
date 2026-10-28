cs_small <- spec_update(spec_small, covariance = "cs")

test_that("stress_curve carries the parameter and tipping_point interpolates the crossing", {
  shift <- function(d, v) { k <- d$ARMCD == "TRT" & !is.na(d$FEV1); d$FEV1[k] <- d$FEV1[k] + v; d }
  cv <- stress_curve(cs_small, values = c(-15, -10, -5, 0, 5), modify = shift, family = "arm shift", anchor = 0)
  expect_equal(cv$param, c(-15, -10, -5, 0, 5)); expect_equal(cv$kind, c("search", "search", "search", "alternative", "search"))
  expect_true(all(diff(cv$estimate) > 0))                       # shifting the active arm up raises the contrast
  tp <- tipping_point(cv)
  expect_equal(nrow(tp), 1L); expect_equal(tp$family, "arm shift"); expect_equal(tp$n, 5L)
  expect_true(is.na(tp$crossing) || (tp$crossing >= -15 && tp$crossing <= 5))
  expect_error(tipping_point(stress_covariance(cs_small, c("us", "cs"))), "no rows")
})

test_that("stress_tipping sets param and plot_pcurve draws it", {
  skip_on_cran()
  skip_if_not_installed("ggplot2")
  tp <- stress_tipping(cs_small, deltas = c(0, -6), m = 2, seed = 2, nbiter = 2)
  expect_equal(tp$param, c(0, -6))
  g <- plot_pcurve(tp); expect_s3_class(g, "ggplot")
  expect_s3_class(plot_pcurve(tp, log_p = TRUE), "ggplot")
})

test_that("swarm packing never overlaps and plot_swarm draws one or several censuses", {
  skip_if_not_installed("ggplot2")
  x <- c(0, 0.5, 1, 1.2, 1.3, 5); r <- c(1, 1, 1.5, 1, 1, 1)
  y <- ballast:::swarm_pack(x, r)
  for (i in 1:5) for (j in (i + 1):6) expect_gte(sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2), r[i] + r[j] - 1e-6)
  cen <- stress_census(cs_small, stress_covariance(cs_small, c("us", "cs", "ar1h", "toep")), stress_covariates(cs_small), stress_loo(cs_small, by = "RACE"))
  expect_s3_class(plot_swarm(cen), "ggplot")
  expect_s3_class(plot_swarm(list(A = cen, B = cen), scale = "estimate"), "ggplot")
  expect_error(plot_swarm(list(1, 2)), "stress_census")
})

test_that("plot_pstrip draws deletion p-values", {
  skip_if_not_installed("ggplot2")
  cen <- stress_census(cs_small, stress_loo(cs_small, by = "RACE"), stress_loo(cs_small, by = "SEX"))
  expect_s3_class(plot_pstrip(cen), "ggplot")
  expect_error(plot_pstrip(stress_census(cs_small, stress_covariance(cs_small, c("us", "cs")))), "no deletion rows")
})

test_that("plot_pcdf draws the p-value distribution for one or several censuses", {
  skip_if_not_installed("ggplot2")
  cs_small <- spec_update(spec_small, covariance = "cs")
  cen <- stress_census(cs_small, stress_covariance(cs_small, c("cs", "ar1h")), stress_loo(cs_small, by = "RACE"))
  expect_s3_class(plot_pcdf(cen), "ggplot"); expect_s3_class(plot_pcdf(list(A = cen, B = cen)), "ggplot")
})

test_that("plot_swarm draws the multi-row dots form from censuses and results, with a caption and a reference line", {
  skip_if_not_installed("ggplot2")
  cen <- stress_census(cs_small, stress_covariance(cs_small, c("us", "cs", "ar1h")), stress_covariates(cs_small), stress_loo(cs_small, by = "RACE"))
  res <- structure(list(census = cen, plan = list(title = "Small plan")), class = "stress_result")
  g <- plot_swarm(list("Row A" = cen, "Row B" = res), reference = 1, reference_label = "1 unit")
  expect_s3_class(g, "ggplot")
  cap <- attr(g, "caption"); expect_length(cap, 2); expect_match(cap[1], "^Row A: [0-9]+ alternative analyses drawn, [0-9]+ deletions drawn, 0 counted rows without an estimate")
  expect_s3_class(plot_swarm(res), "ggplot")                       # one result: dots (not a census, so not the bubble default)
  expect_s3_class(plot_swarm(cen, style = "dots"), "ggplot")
  expect_s3_class(plot_swarm(list(A = cen, B = cen), style = "bubbles", scale = "estimate"), "ggplot")   # the old list form is still reachable
  expect_equal(unname(ballast:::as_census_list(res)) |> length(), 1L); expect_equal(names(ballast:::as_census_list(res)), "Small plan")
  expect_error(plot_swarm(list(1, 2)), "stress_census")
  grp <- ballast:::decision_group(c("covariance structure", "data handling", "leave-one-out: subject", "my family", "re-randomisation test"), c("alternative", "alternative", "deletion", "alternative", "alternative"))
  expect_equal(as.character(grp), c("Statistical decision varied", "Data-handling decision varied", "One unit removed", "Other family", "Statistical decision varied"))
})

test_that("plot_forest draws the filed row and the supplementary rows, side by side for several objects", {
  skip_if_not_installed("ggplot2")
  d <- cs_small$data
  cen <- stress_census(cs_small, stress_covariance(cs_small, "ar1h"),
                       stress_data(cs_small, list("Female only" = d[d$SEX == "Female", ], "Black and White only" = d[d$RACE != "Asian", ])))
  g <- plot_forest(cen); expect_s3_class(g, "ggplot")
  expect_equal(levels(g$data$label), rev(c("As filed", "Female only", "Black and White only")))
  g2 <- plot_forest("Trial alone" = cen, "Pooled" = cen, rows = "Black and White only"); expect_s3_class(g2, "ggplot")
  expect_equal(nlevels(g2$data$object), 2L); expect_equal(nrow(g2$data), 4L)
  expect_error(plot_forest(stress_census(cs_small, stress_covariance(cs_small, "ar1h"))), "no supplementary rows")
})

test_that("plot_pcdf and plot_pstrip accept results as well as censuses", {
  skip_if_not_installed("ggplot2")
  cen <- stress_census(cs_small, stress_covariance(cs_small, c("cs", "ar1h")), stress_loo(cs_small, by = "RACE"))
  res <- structure(list(census = cen, plan = list(title = "Small plan")), class = "stress_result")
  expect_s3_class(plot_pcdf(res), "ggplot"); expect_s3_class(plot_pcdf(list(cen, res)), "ggplot")
  expect_s3_class(plot_pstrip(res), "ggplot")
})
