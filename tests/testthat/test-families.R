test_that("covariance family flags the base structure and keeps the schema", {
  r <- stress_covariance(spec_small, c("us", "cs", "ar1h"))
  expect_s3_class(r, "stress_rows"); expect_equal(nrow(r), 3L)
  expect_equal(names(r), mmrmstress:::ROW_COLS); expect_equal(r$role[1], "sensitivity")
  expect_equal(r$is_base, c(TRUE, FALSE, FALSE)); expect_true(all(r$converged))
  expect_equal(r$covariance, c("us", "cs", "ar1h"))
})

test_that("inference family covers the default settings", {
  r <- stress_inference(spec_small)
  expect_equal(nrow(r), length(default_inference()))
  expect_equal(sum(r$is_base), 1L); expect_equal(r$label[r$is_base], "Satterthwaite")
  expect_true(all(r$converged)); expect_equal(length(unique(round(r$estimate, 8))), 1L)
  expect_error(stress_inference(spec_small, list(list(method = "Residual", vcov = "Asymptotic"))), "named")
})

test_that("covariate family drops each, drops all and adds sets", {
  r <- stress_covariates(spec_full, sets = list("plus weight" = ~ RACE + SEX + FEV1_BL + WEIGHT))
  expect_equal(r$label, c("without RACE", "without SEX", "without FEV1_BL", "no covariates", "plus weight"))
  expect_false(any(r$is_base)); expect_true(all(r$converged))
  expect_equal(r$covariates[4], ""); expect_match(r$covariates[5], "WEIGHT")
  expect_null(stress_covariates(stress_spec(fev_small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO")))
})

test_that("data and population families refit on alternative data", {
  alt <- fev_small; alt$FEV1[alt$USUBJID == "PT1"] <- NA
  r <- stress_data(spec_small, list("PT1 missing" = alt))
  expect_equal(r$family, "data handling"); expect_equal(r$n_subj, stress_fit(spec_small)$n_subj - 1L)
  cs <- spec_update(spec_small, covariance = "cs")   # unstructured does not converge on 28 subjects
  p <- stress_population(cs, list(female = function(d) d$SEX == "Female", male = function(d) d$SEX == "Male"))
  expect_equal(nrow(p), 2L); expect_equal(sum(p$n_subj), stress_fit(spec_small)$n_subj)
  expect_error(stress_data(spec_small, list(alt)), "named")
})

test_that("leave-one-out over subjects and over a grouping variable", {
  by_race <- stress_loo(spec_small, by = "RACE")
  expect_equal(nrow(by_race), 3L); expect_true(all(by_race$kind == "deletion")); expect_match(by_race$note[1], "subjects removed")
  tiny <- stress_spec(fev_small[fev_small$USUBJID %in% paste0("PT", 1:30), ], "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
                      covariates = ~ FEV1_BL, method = "Satterthwaite", vcov = "Asymptotic")
  subj <- stress_loo(tiny)
  expect_equal(nrow(subj), nlevels(tiny$data$USUBJID)); expect_equal(subj$family[1], "leave-one-out: subject")
  expect_true(all(subj$n_subj == nlevels(tiny$data$USUBJID) - 1L | !subj$converged))
})

test_that("specification grid crosses the choices and flags the base cell", {
  g <- stress_grid(spec_small, covariance = c("us", "cs"),
                   inference = list(satt = list(method = "Satterthwaite", vcov = "Asymptotic"), kr = list(method = "Kenward-Roger", vcov = "Kenward-Roger-Linear")),
                   covariates = list(base = ~ FEV1_BL, none = character()))
  expect_equal(nrow(g), 8L); expect_equal(sum(g$is_base), 1L)
  expect_equal(g$label[g$is_base], "us | satt | base | base")
})

test_that("re-randomisation test returns a permutation p and a null distribution", {
  r <- stress_permute(spec_small, n = 19, seed = 7)
  expect_equal(nrow(r), 1L); expect_true(r$p >= 1 / 20 && r$p <= 1)
  expect_length(attr(r, "null"), 19L); expect_true(is.na(r$lcl))
  rs <- stress_permute(spec_small, n = 9, strata = "SEX", statistic = "t", seed = 1)
  expect_match(rs$label, "within SEX")
  expect_error(stress_permute(spec_small, n = 3, strata = "WEIGHT"), "constant within subject")
})

test_that("delta-adjusted MI tipping lowers the estimate as delta falls", {
  r <- stress_tipping(spec_small, deltas = c(0, -8), m = 3, seed = 3, nbiter = 3)
  expect_equal(nrow(r), 2L); expect_equal(r$kind, c("alternative", "search"))
  expect_true(all(r$converged)); expect_lt(r$estimate[2], r$estimate[1])
  expect_match(r$note[1], "m = 3 of 3")
  r2 <- stress_tipping(spec_small, deltas = -8, m = 2, seed = 3, nbiter = 2, shift_visits = "VIS4")
  expect_match(r2$note, "at VIS4")
})
