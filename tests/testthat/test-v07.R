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

test_that("path_changes lists one entry per alternative and skips the pre-specified choice", {
  ch <- path_changes(spec_small, reference = character())
  fam <- vapply(ch, `[[`, "", "family"); lab <- vapply(ch, `[[`, "", "label")
  expect_false("us" %in% lab[fam == "covariance structure"])
  expect_false("Satterthwaite" %in% lab[fam == "inference"])
  expect_true(all(c("covariance structure", "inference", "covariate set", "LS-mean weighting") %in% fam))
  expect_true("reference-based multiple imputation" %in% vapply(path_changes(spec_small, reference = "J2R"), `[[`, "", "family"))
  expect_error(path_changes(spec_small, covariates = list(~ FEV1_BL)), "named")
})

test_that("stress_path changes each family at most once and reports j", {
  ch <- path_changes(spec_small, reference = character())
  p <- stress_path(spec_small, ch, max_j = 4)
  a <- attr(p, "path")
  expect_true(all(p$family == "analytic path")); expect_true(all(p$kind == "search"))
  for (lab in p$label) { parts <- strsplit(lab, " + ", fixed = TRUE)[[1]]; fams <- vapply(parts, function(x) ch[[match(x, vapply(ch, `[[`, "", "label"))]]$family, "")
    expect_equal(anyDuplicated(fams), 0L) }
  expect_true(is.na(a$j) || (a$j >= 1 && a$j <= 4)); expect_equal(a$reached, !is.na(a$j)); expect_false(a$assumption_dependent && !a$reached)
  # a change that must leave the interval: an analysis data set with the active arm shifted far down
  d2 <- spec_small$data; d2$FEV1[d2$ARMCD == "TRT"] <- d2$FEV1[d2$ARMCD == "TRT"] - 50
  p2 <- stress_path(spec_small, c(ch, path_changes(spec_small, covariance = character(), inference = list(), covariates = FALSE, weights = FALSE,
                                                   reference = character(), data = list(shifted = d2))), max_j = 2, direction = "toward_zero")
  expect_equal(attr(p2, "path")$j, 1L); expect_equal(attr(p2, "path")$changes, "shifted")
})

test_that("deletion_benchmark gives the T5 counts", {
  b <- deletion_benchmark(105, z = 2.18)
  expect_equal(unname(b), c(12L, 1L, 14L)); expect_named(b, c("ci", "significance", "reversal"))
  expect_equal(removal_ratio(9, 105), 0.75)
  expect_true(is.na(deletion_benchmark(105, z = 1.5)[["significance"]]))
  expect_true(is.na(deletion_benchmark(20)[["ci"]]))
  expect_true(all(diff(sapply(c(30, 100, 500), function(n) deletion_benchmark(n)[["ci"]])) >= 0))
  expect_error(deletion_benchmark(c(10, 20)))
})

test_that("ranked and greedy deletion searches start from the same participant", {
  d <- simulate_rare_trial(20, delta = 0, defect = "outlier", outlier_size = 6, dropout = 0.001, seed = 8)
  sp <- stress_spec(d, "y", "id", "visit", "arm", "REF", covariates = ~ base, method = "Satterthwaite", vcov = "Asymptotic")
  g <- stress_fragility(sp, "direction", max_k = 3)
  r <- stress_fragility(sp, "direction", max_k = 3, method = "ranked")
  expect_equal(attr(r, "fragility")$method, "ranked"); expect_equal(attr(g, "fragility")$method, "greedy")
  # step 1 of the greedy search is the best single deletion, which is the top of the ranking
  expect_equal(attr(r, "fragility")$subjects[1], attr(g, "fragility")$subjects[1])
  expect_equal(r$estimate[1], g$estimate[1])
  expect_true(all(r$family == "ranked deletion search")); expect_true(all(r$kind == "search"))
})

test_that("ranked removal on clean data needs about the benchmark number of deletions", {
  d <- simulate_rare_trial(100, delta = 4, dropout = 0, site_sd = 0, seed = 21)
  sp <- stress_spec(d, "y", "id", "visit", "arm", "REF", covariates = ~ base, method = "Satterthwaite", vcov = "Asymptotic")
  k <- attr(stress_fragility(sp, "ci", max_k = 40, method = "ranked"), "fragility")$k
  expect_true(!is.na(k)); expect_gt(removal_ratio(k, 200), 0.5); expect_lt(removal_ratio(k, 200), 1.5)
})

test_that("the mutual target catches an outlier that the CI target cannot", {
  d <- simulate_rare_trial(50, delta = 0, defect = "outlier", outlier_size = 30, dropout = 0.001, seed = 8)
  sp <- stress_spec(d, "y", "id", "visit", "arm", "REF", covariates = ~ base, method = "Satterthwaite", vcov = "Asymptotic")
  ci <- attr(stress_fragility(sp, "ci", max_k = 1, method = "ranked"), "fragility")
  mu <- attr(stress_fragility(sp, "mutual", max_k = 1, method = "ranked"), "fragility")
  expect_false(ci$reached)                    # one gross error widens the base CI, so its removal stays inside it (T4b)
  expect_true(mu$reached); expect_equal(mu$k, 1L)
})

test_that("a seed gives the same trial whatever the caller's generator kind, and the kind is restored", {
  a <- simulate_rare_trial(15, delta = 3, population = "mixture", seed = 11)
  old <- RNGkind("L'Ecuyer-CMRG"); on.exit(RNGkind(old[1], old[2], old[3]), add = TRUE)
  set.seed(5); before <- .Random.seed
  b <- simulate_rare_trial(15, delta = 3, population = "mixture", seed = 11)
  expect_identical(a, b)
  expect_equal(RNGkind()[1], "L'Ecuyer-CMRG")
  expect_identical(.Random.seed, before)
})

test_that("the allocation defect gathers fast progressors in the reference arm", {
  d <- simulate_rare_trial(200, population = "mixture", defect = "allocation", fast_to_active = 0.2, seed = 3)
  subj <- unique(d[, c("id", "arm", "fast")])
  expect_equal(sum(subj$arm == "ACT"), 200)
  expect_gt(mean(subj$fast[subj$arm == "REF"]), mean(subj$fast[subj$arm == "ACT"]) + 0.15)
  expect_error(simulate_rare_trial(10, defect = "allocation", fast_to_active = 1, seed = 1), "between 0 and 1")
})

test_that("delta-adjusted imputation is a path change in the reference-based family", {
  ch <- path_changes(spec_small, covariance = character(), inference = list(), covariates = FALSE, weights = FALSE,
                     reference = "J2R", delta_adjusted = c(-5, -10), m = 2)
  expect_equal(vapply(ch, `[[`, "", "label"), c("J2R", "MAR, delta -5", "MAR, delta -10"))
  expect_true(all(vapply(ch, `[[`, "", "family") == "reference-based multiple imputation"))
  expect_equal(ch[[3]]$value$delta, -10)
  p <- stress_path(spec_small, ch[2:3], max_j = 1, direction = "toward_zero", seed = 2)
  r <- stress_reference(spec_small, methods = "MAR", m = 2, seed = 2, delta = if (grepl("-10", p$label[1])) -10 else -5)
  expect_equal(p$estimate[1], r$estimate[1])
})
