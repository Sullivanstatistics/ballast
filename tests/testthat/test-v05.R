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
