test_that("the interval rule ignores a sign change inside the interval; the old rule does not", {
  cov <- stress_covariance(spec_small, c("us", "cs"))
  b <- attr(stress_census(spec_small, cov), "base")
  # a refit inside the base CI with the opposite sign (possible only when the CI spans zero)
  fake <- cov[2, ]; fake$label <- "flip"; fake$p <- 0.9
  fake$estimate <- if (b$lcl < 0 && b$ucl > 0) -sign(b$estimate) * min(abs(b$lcl), abs(b$ucl)) / 2 else NA
  skip_if(is.na(fake$estimate), "base CI excludes zero for this data")
  cen <- stress_census(spec_small, cov, fake)
  expect_equal(stress_verdict(cen)$rule, "interval")
  expect_false(stress_verdict(cen)$stability == "fragile")
  expect_equal(stress_verdict(cen, rule = "interval_or_direction")$stability, "fragile")
  expect_output(print(stress_verdict(cen)), "interval rule")
})

test_that("for a significant base the two rules agree", {
  d <- simulate_rare_trial(30, delta = 12, seed = 4)
  sp <- stress_spec(d, "y", "id", "visit", "arm", "REF", covariates = ~ base + fast, method = "Satterthwaite", vcov = "Asymptotic")
  cen <- stress_census(sp, stress_covariance(sp, c("us", "cs")), stress_loo(sp))
  skip_if(attr(cen, "base")$p >= 0.05, "base not significant")
  expect_equal(stress_verdict(cen)$stability, stress_verdict(cen, rule = "interval_or_direction")$stability)
})

test_that("plans carry the rule into run_plan, the plan text and the SAP text", {
  p <- stress_plan(spec_small, covariance = list(structures = c("us", "cs")), inference = NULL, covariates = NULL, weights = FALSE,
                   loo = NULL, permute = NULL, reference = NULL, estimator = NULL, fragility = NULL)
  expect_equal(p$rule, "interval")
  expect_true(any(grepl("outside the pre-specified 95% confidence interval", plan_lines(p))))
  expect_false(any(grepl("reverses", plan_lines(p))))
  expect_equal(run_plan(p)$verdict$rule, "interval")
  expect_true(any(grepl("\\*fragile\\* if any counted alternative lands outside", stress_sap(p))))
  p_old <- stress_plan(spec_small, covariance = list(structures = c("us", "cs")), inference = NULL, covariates = NULL, weights = FALSE,
                       loo = NULL, permute = NULL, reference = NULL, estimator = NULL, fragility = NULL, rule = "interval_or_direction")
  expect_true(any(grepl("reverses", plan_lines(p_old))))
  p_old$rule <- NULL                        # a plan saved by 0.6 keeps its rule
  expect_equal(run_plan(p_old)$verdict$rule, "interval_or_direction")
})

test_that("simulate_rare_trial is reproducible, restores the RNG and plants its defects", {
  set.seed(99); before <- stats::runif(1); set.seed(99)
  a <- simulate_rare_trial(20, 5, population = "mixture", seed = 1); after <- stats::runif(1)
  expect_equal(before, after)
  expect_identical(a, simulate_rare_trial(20, 5, population = "mixture", seed = 1))
  expect_named(a, c("id", "arm", "site", "base", "fast", "visit", "y"))
  expect_equal(length(unique(a$id)), 40L); expect_equal(sort(unique(a$arm)), c("ACT", "REF"))
  last <- function(d) d[d$visit == "V4", ]
  clean <- simulate_rare_trial(50, 0, seed = 2, dropout = 0.001); out <- simulate_rare_trial(50, 0, seed = 2, dropout = 0.001, defect = "outlier", outlier_size = 10)
  expect_gt(max(out$y), max(clean$y) + 50)
  st <- simulate_rare_trial(200, 40, seed = 3, defect = "site", dropout = 0.001); l <- last(st)
  m <- function(x) mean(x$y[x$arm == "ACT"]) - mean(x$y[x$arm == "REF"])
  expect_gt(m(l[l$site == "site1", ]), 20); expect_lt(abs(m(l[l$site != "site1", ])), 5)
  mn <- simulate_rare_trial(200, 0, seed = 5, defect = "mnar")
  n_obs <- table(mn$arm[mn$visit == "V4"]); expect_lt(n_obs[["ACT"]], n_obs[["REF"]])
  for (pp in c("homogeneous", "heavy")) expect_s3_class(simulate_rare_trial(10, 1, population = pp, seed = 1), "data.frame")
  expect_error(simulate_rare_trial(10, fast_frac = 0.7, fast_effect = 1.6), "below 1")
})

test_that("expected_crossing and expected_exit behave as the analytic section says", {
  expect_equal(expected_crossing(0.05, tau = 0.3), 0.5, tolerance = 1e-3)
  x <- expected_crossing(c(1e-4, 0.001, 0.01, 0.03), tau = 0.3)
  expect_true(all(diff(x) > 0)); expect_lt(x[1], 1e-6)
  expect_gt(expected_crossing(0.029, 0.3), 0.15); expect_lt(expected_crossing(0.029, 0.3), 0.35)
  expect_lt(expected_crossing(0.9, 0.3), 1e-6)
  expect_lt(expected_exit(0.3), 1e-9); expect_gt(expected_exit(1), 0.04)
  expect_error(expected_crossing(0, 0.3)); expect_error(expected_exit(-1))
})
