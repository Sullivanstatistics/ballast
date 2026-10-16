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
