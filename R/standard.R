#' The standard stress test
#'
#' A recommended, citable set of families with fixed settings, so that a
#' statistical analysis plan can say "the standard stress test of ballast"
#' and mean one thing. It contains, in order:
#'
#' 1. covariance structure: `us`, `ar1h`, `ar1`, `cs`, `csh`, `toep`, `toeph`;
#' 2. inference: Satterthwaite, Kenward-Roger, linear Kenward-Roger, residual,
#'    sandwich with between-within df, jackknife sandwich;
#' 3. covariate set: each covariate dropped, all dropped;
#' 4. LS-mean weighting: equal and observed margins;
#' 5. leave-one-out: every subject, and every level of `site` if given;
#' 6. re-randomisation test: 2,000 permutations, within `strata` if given;
#' 7. reference-based multiple imputation: MAR, J2R, CR, CIR, 25 imputations;
#' 8. delta-adjusted multiple imputation over `deltas` if given;
#' 9. estimator class: complete cases, GEE independence, ANCOVA, robust
#'    ANCOVA, plus a random intercept for `site` and cLDA for `baseline` if
#'    given;
#' 10. greedy deletion search for the loss of significance, up to 5 subjects;
#' 11. intercurrent-event strategies if `ice` is given (treatment policy,
#'     hypothetical, while on treatment).
#'
#' @param spec A [stress_spec()].
#' @param site Optional site or centre column (deletions, random intercept,
#'   re-randomisation strata unless `strata` is given).
#' @param strata Optional stratification column for the re-randomisation test.
#' @param baseline Optional baseline column for cLDA.
#' @param deltas Optional shifts for the tipping-point family.
#' @param shift_visits Visits whose imputed values the tipping family shifts;
#'   `NULL` shifts the contrast visit only (the plan text states the visits;
#'   pass every visit level to shift all imputed values).
#' @param ice Optional intercurrent-event table for [stress_estimand()].
#' @param m Imputations for the multiple-imputation families.
#' @param n_perm Permutations for the re-randomisation test.
#' @param max_k Maximum removals in the deletion search.
#' @return A `stress_plan`.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' standard_plan(spec, site = "RACE", baseline = "FEV1_BL")
#' @export
standard_plan <- function(spec, site = NULL, strata = site, baseline = NULL, deltas = NULL, shift_visits = NULL, ice = NULL, m = 25, n_perm = 2000, max_k = 5) {
  check_spec(spec)
  loo <- list(list()); if (!is.null(site)) loo[[2]] <- list(by = site)
  est <- list(estimators = c("complete_cases", "gee_independence", "ancova", "robust_ancova", if (!is.null(site)) "random_intercept", if (!is.null(baseline)) "clda"),
              random = site, baseline = baseline)
  est <- est[!vapply(est, is.null, TRUE)]
  plan <- stress_plan(spec, covariance = list(structures = c("us", "ar1h", "ar1", "cs", "csh", "toep", "toeph")), inference = list(),
                      covariates = list(), weights = TRUE, loo = loo, permute = c(list(n = n_perm), if (!is.null(strata)) list(strata = strata)),
                      tipping = if (!is.null(deltas)) list(deltas = deltas, m = m, shift_visits = if (is.null(shift_visits)) spec$contrast_visit else shift_visits), reference = list(m = m), estimator = est,
                      fragility = list(target = "significance", max_k = max_k),
                      title = sprintf("Standard stress test (ballast %s)", as.character(utils::packageVersion("ballast"))))
  if (!is.null(ice)) plan$families$estimand <- list(ice = ice, strategies = c("treatment_policy", "hypothetical", "while_on_treatment"))
  plan
}

#' Run several plans (several endpoints or comparisons) and compare
#'
#' @param plans A named list of `stress_plan` objects.
#' @param cores,seed Passed to [run_plan()].
#' @return A named list of `stress_result` objects of class `stress_results`;
#'   `summary()` gives one line per plan and [plot_swarm()] accepts the
#'   censuses (`lapply(results, function(r) r$census)`).
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' mk <- function(s) stress_plan(s, covariance = list(structures = c("cs", "ar1h")), inference = NULL,
#'                               covariates = NULL, weights = FALSE, loo = NULL, permute = NULL,
#'                               reference = NULL, estimator = NULL, fragility = NULL)
#' res <- run_plans(list(VIS4 = mk(spec), VIS3 = mk(spec_update(spec, contrast_visit = "VIS3"))))
#' summary(res)
#' @export
run_plans <- function(plans, cores = 1L, seed = 1) {
  if (!is.list(plans) || !all(vapply(plans, inherits, TRUE, "stress_plan"))) stop("plans must be a list of stress_plan objects")
  if (is.null(names(plans))) names(plans) <- paste("Plan", seq_along(plans))
  structure(lapply(plans, run_plan, cores = cores, seed = seed), class = "stress_results")
}

#' @export
summary.stress_results <- function(object, ...) {
  out <- do.call(rbind, lapply(names(object), function(nm) { r <- object[[nm]]; v <- r$verdict; b <- r$base
    data.frame(plan = nm, estimate = b$estimate, lcl = b$lcl, ucl = b$ucl, p = b$p, counted = v$n_alternatives + v$n_deletions, crossed = v$n_crossed,
               outside_ci = v$n_outside_ci, reversed = v$n_reversed, stability = v$stability, stability_sensitivity = v$stability_sensitivity, marginal = v$marginal, stringsAsFactors = FALSE) }))
  rownames(out) <- NULL; out
}

#' @export
print.stress_results <- function(x, ...) { print(summary(x), row.names = FALSE, digits = 3); invisible(x) }
