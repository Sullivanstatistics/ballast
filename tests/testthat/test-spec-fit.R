test_that("spec records the design and builds the model formula", {
  expect_s3_class(spec_full, "stress_spec")
  expect_equal(spec_full$treatment_levels, c("PBO", "TRT"))
  expect_equal(spec_full$contrast_visit, "VIS4")
  expect_equal(spec_full$covariates, c("RACE", "SEX", "FEV1_BL"))
  f <- mmrmstress:::build_formula(spec_full)
  expect_equal(deparse1(f), "FEV1 ~ RACE + SEX + FEV1_BL + ARMCD + AVISIT + ARMCD:AVISIT + us(AVISIT | USUBJID)")
  expect_error(stress_spec(fev[fev$ARMCD == "PBO", ], "FEV1", "USUBJID", "AVISIT", "ARMCD"), "two levels")
  expect_error(stress_spec(fev, "FEV1", "USUBJID", "AVISIT", "ARMCD", contrast_visit = "VIS9"), "not a level")
  expect_output(print(spec_full), "TRT - PBO at VIS4")
})

test_that("spec_update changes settings and validates them", {
  s2 <- spec_update(spec_full, covariance = "ar1h", covariates = ~ FEV1_BL, method = "Satterthwaite", vcov = "Asymptotic")
  expect_equal(s2$covariance, "ar1h"); expect_equal(s2$covariates, "FEV1_BL"); expect_equal(s2$cov_vars, "FEV1_BL")
  expect_error(spec_update(spec_full, subject = "x"), "cannot update")
  expect_error(spec_update(spec_full, covariance = "banana"))
})

test_that("the base fit matches emmeans for the LS-mean contrast (Satterthwaite, model-based vcov)", {
  skip_if_not_installed("emmeans")
  spec <- spec_update(spec_full, method = "Satterthwaite", vcov = "Asymptotic")
  r <- stress_fit(spec)
  expect_true(r$converged); expect_true(r$is_base); expect_equal(r$kind, "alternative")
  fit <- mmrm::mmrm(FEV1 ~ RACE + SEX + FEV1_BL + ARMCD + AVISIT + ARMCD:AVISIT + us(AVISIT | USUBJID), data = fev,
                    control = mmrm::mmrm_control(method = "Satterthwaite"))
  em <- emmeans::emmeans(fit, ~ ARMCD | AVISIT, at = list(AVISIT = "VIS4"))
  ct <- as.data.frame(emmeans::contrast(em, method = list(c(-1, 1))))
  expect_equal(r$estimate, ct$estimate, tolerance = 1e-6)
  expect_equal(r$stderr, ct$SE, tolerance = 1e-6)
  expect_equal(r$df, ct$df, tolerance = 1e-3)
  expect_equal(r$p, ct$p.value, tolerance = 1e-6)
  expect_equal(r$n_subj, 197L)
})

test_that("Kenward-Roger linear and sandwich between-within fits run and differ from Satterthwaite", {
  s <- stress_fit(spec_small)
  kr <- stress_fit(spec_small, method = "Kenward-Roger", vcov = "Kenward-Roger-Linear")
  bw <- stress_fit(spec_small, method = "Between-Within", vcov = "Empirical")
  expect_true(all(c(s$converged, kr$converged, bw$converged)))
  expect_equal(s$estimate, kr$estimate, tolerance = 1e-8)   # same point estimate
  expect_gt(kr$stderr, s$stderr)                            # KR inflates the SE
  expect_true(is.finite(bw$df)); expect_false(isTRUE(all.equal(bw$stderr, s$stderr)))
})

test_that("a single-level class covariate is dropped with a note and alternative data is conformed", {
  d <- fev_small[fev_small$SEX == "Female", ]
  spec <- stress_spec(d, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ SEX + FEV1_BL,
                      method = "Satterthwaite", vcov = "Asymptotic")
  r <- stress_fit(spec)
  expect_true(r$converged); expect_match(r$note, "SEX single-level")
  expect_equal(r$covariates, "FEV1_BL")
  d2 <- fev_small; d2$USUBJID <- as.character(d2$USUBJID); d2$AVISIT <- as.character(d2$AVISIT)
  r2 <- stress_fit(spec_small, data = d2)
  expect_equal(r2$estimate, stress_fit(spec_small)$estimate)
  expect_false(r2$is_base)
})
