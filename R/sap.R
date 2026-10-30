#' Statistical-analysis-plan text for a stress test
#'
#' Returns the paragraphs a statistical analysis plan can carry to
#' pre-specify a stress test: the purpose, the pre-specified analysis, the
#' families and their settings (from the plan), the counting rule, the
#' classification, what will be reported, and the plan's MD5 hash so the run
#' after unblinding can be shown to match what was pre-specified. The same
#' text is installed as a template at
#' `system.file("templates", "sap_stress_test.md", package = "ballast")`.
#'
#' @param plan A [stress_plan()].
#' @param file Optional path to write the text to (Markdown).
#' @param trial A short name for the trial, used in the text.
#' @return A character vector of paragraphs, invisibly if `file` is given.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' cat(stress_sap(standard_plan(spec, site = "RACE"), trial = "Study 001"), sep = "\n\n")
#' @export
stress_sap <- function(plan, file = NULL, trial = "the study") {
  if (!inherits(plan, "stress_plan")) stop("plan must be a stress_plan")
  s <- plan$spec; lines <- plan_lines(plan)
  tf <- tempfile(); writeLines(lines, tf); h <- unname(tools::md5sum(tf)); unlink(tf)
  fam <- lines[grepl("^[0-9]+\\. ", lines)]
  txt <- c(
    sprintf("**Stress test of the primary analysis (pre-specified).** After database lock and unblinding, the primary analysis of %s will be stress-tested with the ballast R package (version %s): the pre-specified model will be refitted under the families of perturbations listed below, and every refit will be judged against the pre-specified estimate, its 95%% confidence interval and the two-sided significance level of %s.",
            trial, as.character(utils::packageVersion("ballast")), format(s$alpha)),
    sprintf("**Pre-specified analysis.** %s ~ %s, with the treatment contrast %s minus %s at %s formed from least-squares means (%s weights), %s degrees of freedom and the %s variance estimator.",
            s$response, paste(c(s$covariates, s$treatment, s$visit, paste0(s$treatment, ":", s$visit), paste0(s$covariance, "(", s$visit, " | ", s$subject, ")")), collapse = " + "),
            s$active, s$reference, s$contrast_visit, s$weights, s$method, s$vcov),
    "**Perturbation families.** The families and their settings are fixed as follows and will not be changed after unblinding:",
    paste0("- ", fam),
    "**Counting rule.** A refit that reproduces the pre-specified analysis exactly is not counted. A specification reached by two families (the same estimate, standard error, degrees of freedom and number of observations) is counted once. Tipping-point grids and the deletion search are searches and are not counted; the delta-zero multiple-imputation analysis is counted. Deletions are counted but summarised separately from alternative analyses. Refits that do not converge are reported and not counted. Refits the plan marks as diagnostic (in the standard stress test, the pre-specified model on complete cases) are fitted, drawn and tabulated with their status but are not counted and do not enter the classification.",
    paste0("**Classification.** The result will be classed *", sub("^fragile", "fragile*", plan_rule_text(plan)), "; otherwise *sensitive* if any counted refit crosses the significance level; otherwise *robust*. The pre-specified p-value will be flagged *marginal* if it lies between half and twice the significance level. The classification will be reported over all counted refits and over the sensitivity analyses alone (those that keep the estimand); alternative data sets, populations, other visits and intercurrent-event strategies are supplementary analyses and will be labelled as such."),
    "**Reporting.** The per-family summary (analyses, significant, crossed, outside the interval, reversed, range as a percentage of the pre-specified estimate, largest shift in pre-specified standard errors), the list of refits that crossed the significance level or left the interval, the deletion-search path, the full census, the bubble-swarm, deletion-strip and tipping-point figures, and a run log with the seed, software versions and the hash of this plan will be provided as an appendix to the clinical study report. Subject identifiers will be masked in any version that leaves the sponsor.",
    sprintf("**Plan hash.** MD5 of the plan text as fixed in this document: `%s`. The run log will carry the same hash.", h))
  if (!is.null(file)) { writeLines(txt, file, sep = "\n\n"); return(invisible(txt)) }
  txt
}
