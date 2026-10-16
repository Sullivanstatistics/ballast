cs_small <- spec_update(spec_small, covariance = "cs")

test_that("observed-margins weighting runs and equals equal weighting without interactions", {
  r <- stress_weights(spec_full)
  expect_equal(nrow(r), 2L); expect_equal(r$is_base, c(TRUE, FALSE)); expect_true(all(r$converged))
  expect_equal(r$estimate[1], r$estimate[2], tolerance = 1e-8)   # no class-by-treatment interaction: identical
  s2 <- spec_update(spec_full, covariates = c("RACE", "SEX", "FEV1_BL", "SEX:ARMCD"))
  r2 <- stress_weights(s2); expect_false(isTRUE(all.equal(r2$estimate[1], r2$estimate[2])))
  expect_equal(spec_update(spec_full, weights = "observed")$weights, "observed")
})

test_that("cLDA runs and reports the baseline-constrained contrast", {
  r <- stress_estimator(spec_full, "clda", baseline = "FEV1_BL")
  expect_true(r$converged); expect_match(r$label, "cLDA"); expect_true(is.finite(r$df))
  expect_message(stress_estimator(spec_full, c("ancova", "clda")), "clda skipped")
})

test_that("a plan prints, runs and reports", {
  skip_on_cran()
  plan <- stress_plan(cs_small, covariance = list(structures = c("cs", "ar1h")), inference = NULL, covariates = NULL, weights = FALSE,
                      loo = list(list(by = "RACE"), list(by = "SEX")), permute = list(n = 9), reference = list(m = 2, methods = c("MAR", "J2R")),
                      estimator = list(estimators = "ancova"), fragility = list(max_k = 1), title = "Test plan")
  expect_s3_class(plan, "stress_plan"); expect_output(print(plan), "Within-subject covariance structure: structures = cs, ar1h")
  expect_output(print(plan), "Leave-one-out deletions: by = RACE | by = SEX")
  res <- run_plan(plan, seed = 3)
  expect_s3_class(res, "stress_result"); expect_equal(names(res$rows), c("covariance", "loo", "permute", "reference", "estimator", "fragility"))
  expect_equal(nrow(res$rows$loo), 5L); expect_s3_class(res$census, "stress_census"); expect_output(print(res), "Verdict")
  skip_if_not_installed("ggplot2")
  td <- file.path(tempdir(), "stress_report_test"); f <- stress_report(res, dir = td, name = "rep")
  expect_true(file.exists(f)); txt <- readLines(f)
  expect_true(any(grepl("## Verdict", txt))); expect_true(any(grepl("Smallest subject set", txt)))
  expect_true(file.exists(file.path(td, "rep_families.png"))); expect_true(file.exists(file.path(td, "rep_pstrip.png")))
})
