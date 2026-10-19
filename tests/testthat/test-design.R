test_that("stress_design returns one row per cell with power and robustness power", {
  skip_on_cran()
  des <- stress_design(n_per_arm = c(12, 16), delta = c(0, 8), n_trials = 2, n_visits = 3, loo = FALSE, seed = 3)
  expect_s3_class(des, "stress_design")
  expect_equal(nrow(des), 4L)
  expect_setequal(paste(des$n_per_arm, des$delta), c("12 0", "16 0", "12 8", "16 8"))
  expect_true(all(des$power >= 0 & des$power <= 1))
  expect_true(all(des$robustness_power <= des$power))
  expect_true(all(is.na(des$robust_given_sig) | des$robust_given_sig + des$sensitive_given_sig + des$fragile_given_sig - 1 < 1e-8))
  expect_equal(nrow(attr(des, "trials")), 8L)
  expect_output(print(des), "robustness power")
})

test_that("stress_design reads a one-subject loss from the leave-one-out rows and can run the tipping grid", {
  skip_on_cran()
  des <- stress_design(n_per_arm = 12, delta = 12, n_trials = 1, n_visits = 3, loo = TRUE, tipping = TRUE, shifts = c(0, 1, 2), m = 2, seed = 5)
  tr <- attr(des, "trials")
  expect_true(is.integer(tr$frag_k) || all(is.na(tr$frag_k)))
  if (isTRUE(tr$significant)) expect_true(is.na(tr$tipping_margin) || tr$tipping_margin >= 0)
  expect_true(all(c("tipping_margin", "tipping_absorbed") %in% names(des)))
})

test_that("plot.stress_design returns a ggplot", {
  skip_on_cran(); skip_if_not_installed("ggplot2")
  des <- stress_design(n_per_arm = c(12, 16), delta = c(0, 8), n_trials = 1, n_visits = 3, loo = FALSE, seed = 7)
  expect_s3_class(plot(des), "ggplot")
})

test_that("seeded functions leave the caller's random-number stream untouched", {
  set.seed(42); before <- .Random.seed
  d <- simulate_trial(10, delta = 2, n_visits = 3, seed = 1)
  expect_identical(.Random.seed, before)
  spec <- stress_spec(d, "y", "id", "visit", "arm", "REF", covariates = ~ base, contrast_visit = "V3", covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
  p <- stress_permute(spec, n = 5, seed = 3)
  expect_identical(.Random.seed, before)
  set.seed(42); a <- runif(1); set.seed(42); invisible(simulate_trial(10, seed = 9)); b <- runif(1)
  expect_identical(a, b)
})
