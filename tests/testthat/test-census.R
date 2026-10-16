test_that("census scores rows against the base and applies the counting rule", {
  skip_on_cran()
  cov <- stress_covariance(spec_small, c("us", "cs", "ar1h"))
  tip <- stress_tipping(spec_small, deltas = c(0, -5), m = 2, seed = 1, nbiter = 2)
  loo <- stress_loo(spec_small, by = "RACE")
  cen <- stress_census(spec_small, cov, tip, loo)
  expect_s3_class(cen, "stress_census")
  expect_equal(nrow(cen), 3L + 2L + 3L)
  b <- attr(cen, "base")
  expect_equal(cen$pct_of_base[cen$is_base], 100)
  expect_equal(cen$counted, c(FALSE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE))  # base, 2 cov, MI delta 0, search, 3 deletions
  expect_true(all(cen$inside_ci[cen$is_base]))
  s <- summary(cen)
  expect_s3_class(s, "summary.stress_census")
  expect_equal(s$family[nrow(s)], "All"); expect_equal(s$n[nrow(s)], sum(cen$counted))
  expect_output(print(s), "Base analysis")
})

test_that("verdict classifies robust, sensitive and fragile", {
  cov <- stress_covariance(spec_small, c("us", "cs"))
  cen <- stress_census(spec_small, cov)
  v <- stress_verdict(cen)
  expect_s3_class(v, "stress_verdict"); expect_true(v$stability %in% c("robust", "sensitive", "fragile"))
  expect_output(print(v), "Verdict")
  # force a fragile row: an estimate outside the base CI with reversed sign
  fake <- cov[2, ]; fake$estimate <- -abs(attr(cen, "base")$ucl) * 10; fake$label <- "fake"
  v2 <- stress_verdict(stress_census(spec_small, cov, fake))
  expect_equal(v2$stability, "fragile"); expect_equal(nrow(v2$fragile_rows), 1L)
  # a significance crossing inside the CI is sensitive
  fake2 <- cov[2, ]; fake2$p <- if (attr(cen, "base")$p < 0.05) 0.5 else 0.001; fake2$estimate <- attr(cen, "base")$estimate; fake2$label <- "fake2"
  v3 <- stress_verdict(stress_census(spec_small, cov, fake2))
  expect_equal(v3$stability, "sensitive")
  expect_true(is.logical(v3$marginal))
})

test_that("plot returns a ggplot", {
  skip_if_not_installed("ggplot2")
  cen <- stress_census(spec_small, stress_covariance(spec_small, c("us", "cs")), stress_loo(spec_small, by = "RACE"))
  expect_s3_class(plot(cen), "ggplot")
})
