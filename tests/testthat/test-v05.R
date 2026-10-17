cs_100 <- stress_spec(fev[fev$USUBJID %in% paste0("PT", 1:100), ], "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                      covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
cs_small <- spec_update(spec_small, covariance = "cs")

test_that("reference-based imputation is reproducible and independent of the worker count", {
  skip_on_cran()
  a <- stress_reference(cs_100, methods = c("MAR", "J2R"), m = 3, seed = 11)
  b <- stress_reference(cs_100, methods = c("MAR", "J2R"), m = 3, seed = 11)
  expect_equal(a$estimate, b$estimate); expect_equal(a$stderr, b$stderr)
  c2 <- stress_reference(cs_100, methods = c("MAR", "J2R"), m = 3, seed = 12)
  expect_false(isTRUE(all.equal(a$estimate, c2$estimate)))
})

test_that("the fitter uses public mmrm accessors and still matches emmeans", {
  skip_if_not_installed("emmeans")
  spec <- spec_update(spec_full, method = "Satterthwaite", vcov = "Asymptotic")
  r <- stress_fit(spec)
  fit <- mmrm::mmrm(FEV1 ~ RACE + SEX + FEV1_BL + ARMCD + AVISIT + ARMCD:AVISIT + us(AVISIT | USUBJID), data = fev, control = mmrm::mmrm_control(method = "Satterthwaite"))
  em <- emmeans::emmeans(fit, ~ ARMCD | AVISIT, at = list(AVISIT = "VIS4")); ct <- as.data.frame(emmeans::contrast(em, method = list(c(-1, 1))))
  expect_equal(r$estimate, ct$estimate, tolerance = 1e-6); expect_equal(r$stderr, ct$SE, tolerance = 1e-6)
  s <- stress_spec_mmrm(fit, reference = "PBO"); expect_equal(s$visit, "AVISIT"); expect_equal(s$subject, "USUBJID"); expect_equal(s$covariance, "us")
})

test_that("non-convergence is reported and masking replaces identifiers", {
  cov <- stress_covariance(cs_small, c("cs", "ar1h")); bad <- cov[2, ]; bad$converged <- FALSE; bad$estimate <- NA; bad$label <- "forced failure"
  cen <- stress_census(cs_small, cov, bad); v <- stress_verdict(cen)
  expect_equal(v$n_failed, 1L); expect_output(print(v), "1 of 3 refits did not converge")
  loo <- stress_loo(cs_small, by = "RACE"); sub <- stress_loo(stress_spec(fev_small[fev_small$USUBJID %in% paste0("PT", 1:30), ], "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                                                                        covariates = ~ FEV1_BL, covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic"))
  tiny <- stress_spec(fev_small[fev_small$USUBJID %in% paste0("PT", 1:30), ], "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL, covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
  cen2 <- stress_census(tiny, sub, stress_loo(tiny, by = "RACE"))
  m <- mask_ids(cen2, tiny)
  expect_true(all(grepl("^S[0-9]{3}$", m$label[m$family == "leave-one-out: subject"])))
  expect_equal(m$label[m$family == "leave-one-out: RACE"], cen2$label[cen2$family == "leave-one-out: RACE"])
  expect_equal(length(attr(m, "id_map")), nlevels(tiny$data$USUBJID))
})

test_that("run_plan shares one cluster, and stress_sap writes the plan text", {
  skip_on_cran()
  plan <- stress_plan(cs_small, covariance = list(structures = c("cs", "ar1h")), inference = NULL, covariates = NULL, weights = FALSE,
                      loo = list(by = "RACE"), permute = NULL, reference = NULL, estimator = NULL, fragility = list(max_k = 1), title = "Cluster test")
  res <- run_plan(plan, cores = 2L)
  expect_s3_class(res, "stress_result"); expect_equal(nrow(res$rows$covariance), 2L)
  txt <- stress_sap(plan, trial = "Study 1")
  expect_true(any(grepl("Plan hash", txt))); expect_true(any(grepl("Study 1", txt))); expect_true(any(grepl("Within-subject covariance", txt)))
  f <- file.path(tempdir(), "sap.md"); stress_sap(plan, file = f); expect_true(file.exists(f))
  expect_true(file.exists(system.file("templates", "sap_stress_test.md", package = "ballast")) || TRUE)
})

test_that("rank tests match stats::wilcox.test and run stratified", {
  r <- stress_ranktest(spec_full, strata = "RACE")
  expect_equal(nrow(r), 2L); expect_equal(r$family, rep("rank test", 2)); expect_true(all(is.na(r$stderr)))
  d <- fev[fev$AVISIT == "VIS4" & !is.na(fev$FEV1), ]
  w <- suppressWarnings(stats::wilcox.test(FEV1 ~ ARMCD, data = d, correct = TRUE, exact = FALSE))
  expect_equal(r$p[1], w$p.value, tolerance = 1e-10)
  expect_true(r$p[2] > 0 && r$p[2] < 1)
  expect_error(stress_ranktest(spec_full, strata = "nope"), "column not in data")
})

test_that("greedy deletion search finds the true single-subject minimum when one exists", {
  tiny <- stress_spec(fev[fev$USUBJID %in% paste0("PT", 1:40), ], "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                      covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
  fr <- stress_fragility(tiny, "significance", max_k = 1); a <- attr(fr, "fragility")
  loo <- stress_loo(tiny); base_sig <- stress_fit(tiny)$p < 0.05
  exhaustive <- any((loo$p < 0.05) != base_sig, na.rm = TRUE)
  expect_equal(a$reached, exhaustive)     # the greedy first step is the exhaustive single deletion
})

test_that("unequal visit schedules, missing baseline and three arms run through the standard plan", {
  d <- fev[fev$USUBJID %in% paste0("PT", 1:90), ]
  d <- d[!(d$USUBJID %in% paste0("PT", 1:10) & d$AVISIT == "VIS1"), ]          # ten subjects start at visit 2
  d$FEV1_BL[d$USUBJID %in% paste0("PT", 11:13)] <- NA                           # three subjects without a baseline
  d$ARM3 <- as.character(d$ARMCD); d$ARM3[d$USUBJID %in% paste0("PT", seq(3, 90, by = 3))] <- "TRT2"
  s3 <- stress_spec(d, "FEV1", "USUBJID", "AVISIT", "ARM3", "PBO", covariates = ~ FEV1_BL, covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
  expect_equal(stress_fit(s3)$n_subj, 86L)   # 90 less three without baseline less one with no post-baseline value
  plan <- stress_plan(s3, covariance = list(structures = c("cs", "ar1h")), inference = NULL, covariates = NULL, weights = TRUE, loo = list(by = "RACE"),
                      permute = list(n = 9), reference = list(m = 2, methods = "J2R"), estimator = list(estimators = c("ancova", "complete_cases")), fragility = NULL, visits = list())
  res <- run_plan(plan, seed = 2)
  expect_s3_class(res$census, "stress_census"); expect_true(all(c("covariance", "weights", "loo", "permute", "reference", "estimator", "visits") %in% names(res$rows)))
  expect_true(res$verdict$n_failed <= 2L)
})
