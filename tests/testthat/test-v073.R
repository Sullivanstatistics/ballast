cs_small <- spec_update(spec_small, covariance = "cs")

test_that("every family name the package produces has a decision group; only a user family is Other", {
  fams <- c("covariance structure", "inference", "covariate set", "LS-mean weighting", "specification grid", "estimator class", "rank test",
            "contrast visit", "re-randomisation test", "data handling", "analysis population", "intercurrent-event strategy",
            "reference-based multiple imputation", "delta-adjusted multiple imputation", "perturbation curve")
  grp <- ballast:::decision_group(fams, rep("alternative", length(fams)))
  expect_false(any(as.character(grp) == "Other family"))
  expect_equal(as.character(ballast:::decision_group(c("leave-one-out: subject", "leave-one-out: SITE"), c("deletion", "deletion"))), rep("One unit removed", 2))
  expect_equal(as.character(ballast:::decision_group("my family", "alternative")), "Other family")
})

test_that("the standard plan fits the complete-case refit as a diagnostic: drawn and tabulated, not counted", {
  skip_on_cran()
  sp <- standard_plan(cs_small, n_perm = 20, m = 2, max_k = 1)
  expect_equal(sp$families$estimator$diagnostic, "complete_cases")
  expect_output(print(sp), "The complete cases refit is fitted, drawn and tabulated as a diagnostic and is not counted")
  expect_match(paste(stress_sap(sp), collapse = " "), "marks as diagnostic")
  res <- suppressWarnings(run_plan(sp, seed = 3))
  cen <- res$census; cc <- cen[cen$family == "estimator class" & grepl("complete cases", cen$label), ]
  expect_equal(nrow(cc), 1L); expect_equal(cc$kind, "diagnostic"); expect_false(cc$counted); expect_true(cc$converged); expect_true(is.finite(cc$estimate))
  s <- summary(cen); dl <- s[s$kind == "diagnostic", ]
  expect_equal(nrow(dl), 1L); expect_false(dl$counted); expect_equal(dl$n, 1L); expect_equal(dl$family, "estimator class")
  expect_true(all(s$counted[s$kind != "diagnostic"]))
  expect_equal(s$n[s$family == "All"], sum(cen$counted))
  v <- res$verdict
  expect_equal(v$n_alternatives, sum(cen$counted & cen$kind == "alternative")); expect_equal(v$n_diagnostic, 1L)
  expect_false(any(grepl("complete cases", v$fragile_rows$label))); expect_false(any(grepl("complete cases", v$crossed_rows$label)))
  expect_output(print(v), "1 diagnostic refit fitted and shown, not counted")
  # called directly, stress_estimator() still counts the complete-case row
  expect_equal(stress_estimator(cs_small, "complete_cases")$kind, "alternative")
  expect_equal(stress_estimator(cs_small, c("complete_cases", "ancova"), diagnostic = "complete_cases")$kind, c("diagnostic", "alternative"))
  skip_if_not_installed("ggplot2")
  g <- plot_swarm(res); expect_s3_class(g, "ggplot")
  pts <- do.call(rbind, lapply(g$layers, function(l) if (is.data.frame(l$data) && all(c("group", "diagnostic") %in% names(l$data))) l$data[, c("group", "diagnostic")]))
  expect_false("Other family" %in% as.character(pts$group))        # the legend (drop = TRUE) shows only groups present in the data
  expect_equal(sum(pts$diagnostic), 1L)                             # the complete-case dot is drawn
  expect_match(attr(g, "caption"), "1 diagnostic refits drawn hollow and not counted")
  expect_s3_class(plot(cen), "ggplot")
  td <- file.path(tempdir(), "v073"); p <- stress_tables(res, dir = td, formats = "csv")
  t1 <- utils::read.csv(p[grepl("summary", p)], check.names = FALSE)
  expect_true("Counted" %in% names(t1)); expect_equal(t1$Counted[t1$Kind == "diagnostic"], "no"); expect_true(all(t1$Counted[t1$Kind != "diagnostic"] == "yes"))
  f <- stress_report(res, dir = td); expect_match(paste(readLines(f), collapse = "\n"), "1 diagnostic refit was fitted and shown")
})
