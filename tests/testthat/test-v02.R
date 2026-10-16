cs_small <- spec_update(spec_small, covariance = "cs")
cs_100 <- stress_spec(fev[fev$USUBJID %in% paste0("PT", 1:100), ], "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
                      covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")

test_that("role is carried on rows and reported by the census", {
  expect_equal(stress_fit(cs_small)$role, "sensitivity")
  alt <- fev_small; alt$FEV1[alt$USUBJID == "PT1"] <- NA
  d <- stress_data(cs_small, list("PT1 missing" = alt)); expect_equal(d$role, "supplementary")
  d2 <- stress_data(cs_small, list("PT1 missing" = alt), role = "sensitivity"); expect_equal(d2$role, "sensitivity")
  expect_error(stress_fit(cs_small, role = "other"))
  cen <- stress_census(cs_small, stress_covariance(cs_small, c("us", "cs", "ar1h")), d)
  s <- summary(cen); expect_true("role" %in% names(s)); expect_true(any(s$family == "All sensitivity"))
  v <- stress_verdict(cen); expect_true(v$stability_sensitivity %in% c("robust", "sensitive", "fragile"))
  expect_equal(v$n_supplementary, 1L); expect_output(print(v), "sensitivity analyses")
})

test_that("reference-based imputation runs under every assumption and orders as expected", {
  r <- stress_reference(cs_100, methods = c("MAR", "J2R", "CR", "CIR"), m = 3, seed = 4)
  expect_equal(nrow(r), 4L); expect_true(all(r$converged)); expect_equal(r$role, rep("sensitivity", 4))
  expect_equal(r$kind, rep("alternative", 4)); expect_match(r$note[1], "m = 3 of 3")
  # the active arm's effect is positive on fev_data: reference-based assumptions pull the contrast towards zero
  expect_lt(r$estimate[r$label == "J2R"], r$estimate[r$label == "MAR"])
  expect_lt(r$estimate[r$label == "CR"], r$estimate[r$label == "MAR"])
  rd <- stress_reference(cs_100, methods = "J2R", m = 2, seed = 4, delta = -5)
  expect_equal(rd$param, -5); expect_match(rd$label, "delta -5")
  expect_error(stress_reference(cs_100, methods = "banana"))
})

test_that("greedy fragility search removes subjects until the target is reached", {
  fr <- stress_fragility(cs_100, target = "significance", max_k = 3)
  a <- attr(fr, "fragility")
  expect_equal(a$target, "significance"); expect_true(nrow(fr) >= 1L && nrow(fr) <= 3L)
  expect_equal(fr$param, seq_len(nrow(fr))); expect_true(all(fr$kind == "search"))
  expect_equal(length(a$subjects), nrow(fr))
  if (a$reached) expect_true((fr$p[nrow(fr)] < 0.05) != (a$base_p < 0.05))
  fr2 <- stress_fragility(cs_small, target = "direction", max_k = 1, candidates = c("PT1", "PT2", "PT3"))
  expect_true(attr(fr2, "fragility")$subjects %in% c("PT1", "PT2", "PT3"))
  expect_error(stress_fragility(cs_small, candidates = "nobody"), "subject identifiers")
})

test_that("estimator family runs each estimator and reports the same contrast type", {
  skip_if_not_installed("nlme"); skip_if_not_installed("MASS")
  r <- stress_estimator(spec_full, random = "RACE")
  expect_equal(nrow(r), 5L); expect_true(all(r$converged)); expect_equal(unique(r$family), "estimator class")
  cc <- r$label == "MMRM on complete cases"   # fev_data has heavy missingness: only 39 of 197 subjects are complete
  expect_true(all(abs(r$estimate[!cc] - stress_fit(spec_full)$estimate) < 1.5))   # the others agree on the broad answer
  expect_true(is.na(r$df[r$label == "MM robust regression at the contrast visit"]))
  expect_equal(r$df[r$label == "ANCOVA at the contrast visit"], sum(!is.na(fev$FEV1[fev$AVISIT == "VIS4"])) - 6)   # intercept, 2 race, sex, baseline, arm
  expect_message(stress_estimator(spec_full, c("ancova", "random_intercept")), "random_intercept skipped")
})
