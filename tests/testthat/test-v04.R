cs_small <- spec_update(spec_small, covariance = "cs")

test_that("constructors build specs from an mmrm fit and from an ADaM BDS", {
  fit <- mmrm::mmrm(FEV1 ~ RACE + SEX + FEV1_BL + ARMCD * AVISIT + us(AVISIT | USUBJID), data = fev)
  s <- stress_spec_mmrm(fit, reference = "PBO")
  expect_equal(s$treatment, "ARMCD"); expect_equal(sort(s$covariates), sort(c("RACE", "SEX", "FEV1_BL"))); expect_equal(s$covariance, "us")
  expect_equal(s$method, "Satterthwaite"); expect_equal(stress_fit(s)$estimate, stress_fit(spec_update(spec_full, method = "Satterthwaite", vcov = "Asymptotic"))$estimate, tolerance = 1e-8)
  bds <- transform(fev, PARAMCD = "FEV1", CHG = FEV1 - FEV1_BL, BASE = FEV1_BL, AVISITN = VISITN, TRTP = ARMCD, ANL01FL = "Y")
  a <- stress_spec_adam(bds, "FEV1", response = "CHG", reference = "PBO")
  expect_equal(a$covariates, "BASE"); expect_equal(a$visit_levels, c("VIS1", "VIS2", "VIS3", "VIS4")); expect_true(stress_fit(a)$converged)
  expect_error(stress_spec_adam(bds, "NOPE"), "no records")
})

test_that("three arms: active is chosen and the contrast is active minus reference", {
  d <- fev_small; d$ARM3 <- as.character(d$ARMCD); d$ARM3[d$USUBJID %in% paste0("PT", seq(2, 60, by = 3))] <- "TRT2"
  s3 <- stress_spec(d, "FEV1", "USUBJID", "AVISIT", "ARM3", "PBO", covariates = ~ FEV1_BL, covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
  expect_equal(s3$active, "TRT"); expect_equal(length(s3$treatment_levels), 3L)
  r1 <- stress_fit(s3); r2 <- stress_fit(spec_update(s3, active = "TRT2"))
  expect_true(r1$converged && r2$converged); expect_false(isTRUE(all.equal(r1$estimate, r2$estimate)))
  expect_output(print(s3), "arms: PBO, TRT, TRT2")
  expect_error(spec_update(s3, active = "PBO"), "other than the reference")
  expect_true(all(stress_covariance(s3, c("cs", "ar1h"))$converged))
})

test_that("visits family and estimand family derive supplementary rows", {
  v <- stress_visits(cs_small)
  expect_equal(nrow(v), 4L); expect_equal(v$role, rep("supplementary", 4)); expect_equal(sum(v$is_base), 1L)
  ice <- data.frame(USUBJID = c("PT2", "PT5", "PT9"), AVISIT = c("VIS3", "VIS2", "VIS4"), type = c("disc", "disc", "rescue"))
  e <- stress_estimand(cs_small, ice, strategies = list(disc = c("treatment_policy", "hypothetical", "while_on_treatment"), rescue = c("treatment_policy", "composite")), composite_value = 20)
  expect_equal(nrow(e), 6L); expect_equal(sum(e$is_base), 1L); expect_equal(e$role[!e$is_base], rep("supplementary", 5))
  expect_equal(length(attr(e, "data")), 6L)
  hyp <- attr(e, "data")[["disc: hypothetical | rescue: treatment_policy"]]
  expect_true(all(is.na(hyp$FEV1[hyp$USUBJID == "PT2" & hyp$AVISIT %in% c("VIS3", "VIS4")])))
  expect_error(stress_estimand(cs_small, ice, strategies = "composite"), "composite_value")
})

test_that("stress_explain attributes a shift to subjects", {
  cen <- stress_census(cs_small, stress_covariance(cs_small, c("cs", "ar1h")))
  ex <- stress_explain(cs_small, cen[cen$label == "ar1h", ], top = 5)
  expect_s3_class(ex, "stress_explanation"); expect_equal(nrow(ex), nlevels(cs_small$data$USUBJID))
  expect_true(all(abs(ex$difference) >= 0)); expect_output(print(ex), "Alternative: covariance structure / ar1h")
  expect_equal(unname(attr(ex, "estimates")["base"]), stress_fit(cs_small)$estimate)
})

test_that("standard plan, run_plans, tables, log, html and calibration", {
  skip_on_cran()
  sp <- standard_plan(spec_full, site = "RACE", baseline = "FEV1_BL", deltas = c(0, -5))
  expect_s3_class(sp, "stress_plan"); expect_true(all(c("covariance", "loo", "permute", "reference", "tipping", "estimator", "fragility") %in% names(sp$families)))
  expect_output(print(sp), "Standard stress test")
  mk <- function(s) stress_plan(s, covariance = list(structures = c("cs", "ar1h")), inference = NULL, covariates = NULL, weights = FALSE, loo = list(by = "RACE"), permute = NULL,
                                reference = NULL, estimator = NULL, fragility = list(max_k = 1))
  res <- run_plans(list(VIS4 = mk(cs_small), VIS3 = mk(spec_update(cs_small, contrast_visit = "VIS3"))))
  expect_s3_class(res, "stress_results"); s <- summary(res); expect_equal(s$plan, c("VIS4", "VIS3")); expect_output(print(res), "stability")
  td <- file.path(tempdir(), "deliv"); p <- stress_tables(res$VIS4, dir = td, formats = "csv")
  expect_true(all(file.exists(p))); expect_true(any(grepl("fragility", p)))
  lg <- stress_log(res$VIS4, file = file.path(td, "log.json")); expect_equal(nchar(lg$plan_md5), 32L); expect_true(file.exists(file.path(td, "log.json")))
  skip_if_not_installed("flextable"); skip_if_not_installed("officer")
  p2 <- stress_tables(res$VIS4, dir = td, formats = c("docx", "rtf")); expect_true(any(grepl("\\.docx$", p2))); expect_true(any(grepl("\\.rtf$", p2)))
  skip_if_not_installed("plotly"); skip_if_not_installed("htmlwidgets")
  f <- stress_html(res$VIS4, file.path(td, "r.html")); expect_true(file.exists(f)); expect_gt(file.size(f), 3000)
})

test_that("simulate_trial and a tiny calibration run", {
  skip_on_cran()
  d <- simulate_trial(20, delta = 5, seed = 2); expect_true(all(c("id", "arm", "base", "visit", "y") %in% names(d))); expect_true(nrow(d) <= 160)
  cal <- stress_calibrate(n_per_arm = 25, power = c(0, 0.8), n_trials = 2, seed = 5)
  expect_s3_class(cal, "stress_calibration"); expect_equal(nrow(cal), 2L); expect_output(print(cal), "calibration")
})
