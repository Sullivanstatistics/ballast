#' Pre-specify a stress test
#'
#' A plan names the families to run and their settings before unblinding, so
#' the stress test can be written into a statistical analysis plan and run
#' with one call ([run_plan()]). Each family argument is `NULL` to skip the
#' family, an empty `list()` to run it with its defaults, or a named list of
#' arguments for the family function. Printing the plan gives the text a
#' statistical analysis plan can carry.
#'
#' @param spec A [stress_spec()]: the pre-specified analysis.
#' @param covariance Arguments for [stress_covariance()].
#' @param inference Arguments for [stress_inference()].
#' @param covariates Arguments for [stress_covariates()].
#' @param weights `TRUE` to run [stress_weights()].
#' @param population Arguments for [stress_population()] (needs `rules`).
#' @param data Arguments for [stress_data()] (needs `alternatives`).
#' @param loo Arguments for [stress_loo()]; a list of lists runs it several
#'   times (subjects and a site variable, say).
#' @param grid Arguments for [stress_grid()].
#' @param permute Arguments for [stress_permute()].
#' @param tipping Arguments for [stress_tipping()] (needs `deltas`).
#' @param reference Arguments for [stress_reference()].
#' @param estimator Arguments for [stress_estimator()].
#' @param fragility Arguments for [stress_fragility()].
#' @param curve Arguments for [stress_curve()] (needs `values` and `modify`).
#' @param estimand Arguments for [stress_estimand()] (needs `ice`).
#' @param visits Arguments for [stress_visits()].
#' @param title A title for the plan.
#' @param rule Classification rule passed to [stress_verdict()]: `"interval"`
#'   (default) or `"interval_or_direction"`.
#' @return An object of class `stress_plan`.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' plan <- stress_plan(spec, covariance = list(structures = c("us", "cs", "ar1h")),
#'                     inference = list(), covariates = list(), loo = list(by = "RACE"),
#'                     permute = NULL, reference = NULL, estimator = list(estimators = "ancova"),
#'                     fragility = list(max_k = 2))
#' plan
#' @export
stress_plan <- function(spec, covariance = list(), inference = list(), covariates = list(), weights = TRUE, population = NULL,
                        data = NULL, loo = list(), grid = NULL, permute = list(n = 2000), tipping = NULL, reference = list(),
                        estimator = list(), fragility = list(), curve = NULL, estimand = NULL, visits = NULL, title = "Pre-specified stress test",
                        rule = c("interval", "interval_or_direction")) {
  check_spec(spec); rule <- match.arg(rule)
  fams <- list(covariance = covariance, inference = inference, covariates = covariates, weights = if (isTRUE(weights)) list() else NULL,
               population = population, data = data, loo = loo, grid = grid, permute = permute, tipping = tipping,
               reference = reference, estimator = estimator, fragility = fragility, curve = curve, estimand = estimand, visits = visits)
  fams <- fams[!vapply(fams, is.null, TRUE)]
  structure(list(spec = spec, families = fams, title = title, rule = rule), class = "stress_plan")
}

FAMILY_FUN <- c(covariance = "stress_covariance", inference = "stress_inference", covariates = "stress_covariates", weights = "stress_weights",
                population = "stress_population", data = "stress_data", loo = "stress_loo", grid = "stress_grid", permute = "stress_permute",
                tipping = "stress_tipping", reference = "stress_reference", estimator = "stress_estimator", fragility = "stress_fragility", curve = "stress_curve",
                estimand = "stress_estimand", visits = "stress_visits")

plan_lines <- function(plan) {
  s <- plan$spec; f <- plan$families
  fmt <- function(x) if (is.null(x) || !length(x)) "defaults" else paste(vapply(names(x), function(n) {
    v <- x[[n]]; paste0(n, " = ", if (is.function(v)) "<function>" else if (is.data.frame(v)) sprintf("<data, %d rows>", nrow(v)) else if (is.list(v)) paste0("<", length(v), " items: ", paste(names(v), collapse = ", "), ">") else if (inherits(v, "formula")) deparse1(v) else paste(as.character(v), collapse = ", ")) }, ""), collapse = "; ")
  desc <- c(covariance = "Within-subject covariance structure", inference = "Degrees-of-freedom method and variance estimator", covariates = "Covariate set",
            weights = "Least-squares-mean weighting (equal versus observed margins)", population = "Analysis population", data = "Alternative analysis data sets",
            loo = "Leave-one-out deletions", grid = "Crossed specification grid", permute = "Re-randomisation test", tipping = "Delta-adjusted multiple imputation (tipping point)",
            reference = "Reference-based multiple imputation (MAR, J2R, CR, CIR)", estimator = "Estimator class", fragility = "Smallest set of subjects that changes the conclusion",
            curve = "Continuous data perturbation", estimand = "Intercurrent-event strategies", visits = "Contrast at every visit")
  c(plan$title, "",
    sprintf("Pre-specified analysis: %s ~ %s; contrast %s minus %s at %s; %s df, %s variance; alpha %s; %s LS-mean weights.",
            s$response, paste(c(s$covariates, s$treatment, s$visit, paste0(s$treatment, ":", s$visit), paste0(s$covariance, "(", s$visit, " | ", s$subject, ")")), collapse = " + "),
            s$active, s$reference, s$contrast_visit, s$method, s$vcov, format(s$alpha), s$weights),
    "", "Perturbation families, run after unblinding exactly as listed; every refit is judged against the pre-specified estimate,",
    "its 95% confidence interval and alpha.", paste0("Classification: ", plan_rule_text(plan), "; otherwise sensitive if any crosses alpha; otherwise robust."),
    "Specifications reached by two families are counted once; tipping-point grids are searches and are not counted; deletions are",
    "counted separately.", "",
    vapply(seq_along(f), function(i) {
      nm <- names(f)[i]; x <- f[[i]]
      if (nm == "loo" && length(x) && is.list(x[[1]])) sprintf("%d. %s: %s", i, desc[[nm]], paste(vapply(x, fmt, ""), collapse = " | "))
      else if (nm == "estimator" && length(x$diagnostic)) sprintf("%d. %s: %s. The %s refit is fitted, drawn and tabulated as a diagnostic and is not counted.", i, desc[[nm]], fmt(x), paste(gsub("_", " ", x$diagnostic), collapse = " and "))
      else sprintf("%d. %s: %s", i, desc[[nm]], fmt(x)) }, ""))
}

#' @export
print.stress_plan <- function(x, ...) { cat(plan_lines(x), sep = "\n"); invisible(x) }

#' Run a pre-specified stress test
#'
#' Runs every family in a [stress_plan()], assembles the census and the
#' verdict, and keeps the rows by family.
#'
#' @param plan A `stress_plan`.
#' @param cores Worker processes; the cluster is started once and shared by
#'   every family.
#' @param seed Seed passed to the families that take one, unless the plan
#'   sets it.
#' @return An object of class `stress_result`: `plan`, `rows` (a list of
#'   `stress_rows` by family), `census`, `verdict`, `base` and `elapsed`.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' plan <- stress_plan(spec, covariance = list(structures = c("cs", "ar1h")),
#'                     inference = NULL, covariates = NULL, weights = FALSE,
#'                     loo = list(by = "RACE"), permute = list(n = 9), reference = NULL,
#'                     estimator = list(estimators = "ancova"), fragility = list(max_k = 1))
#' res <- run_plan(plan)
#' res
#' @export
run_plan <- function(plan, cores = 1L, seed = 1) {
  if (!inherits(plan, "stress_plan")) stop("plan must be a stress_plan")
  t0 <- Sys.time(); spec <- plan$spec; rows <- list()
  if (is.numeric(cores) && cores > 1L) {   # one cluster for the whole plan
    cl <- parallel::makeCluster(as.integer(cores)); on.exit(parallel::stopCluster(cl), add = TRUE)
    parallel::clusterEvalQ(cl, { requireNamespace("ballast", quietly = TRUE); NULL }); cores <- cl
  }
  for (nm in names(plan$families)) {
    x <- plan$families[[nm]]; fun <- get(FAMILY_FUN[[nm]], envir = asNamespace("ballast"))
    calls <- if (nm == "loo" && length(x) && is.list(x[[1]])) x else list(x)
    out <- lapply(calls, function(args) {
      args <- c(list(spec = spec), args)
      if ("cores" %in% names(formals(fun)) && is.null(args$cores)) args$cores <- cores
      if ("seed" %in% names(formals(fun)) && is.null(args$seed)) args$seed <- seed
      tryCatch(do.call(fun, args), error = function(e) { warning(nm, " failed: ", conditionMessage(e)); NULL })
    })
    out <- out[!vapply(out, is.null, TRUE)]
    if (length(out) == 1L) rows[[nm]] <- out[[1]] else if (length(out)) rows[[nm]] <- bind_rows_(out)   # a single call keeps its attributes (fragility, null)
  }
  base <- stress_fit(spec)
  census <- do.call(stress_census, c(list(spec = spec), unname(rows), list(base = base)))
  structure(list(plan = plan, rows = rows, census = census, verdict = stress_verdict(census, rule = plan_rule(plan)), base = base,
                 elapsed = difftime(Sys.time(), t0, units = "mins")), class = "stress_result")
}

#' @export
print.stress_result <- function(x, ...) {
  cat(x$plan$title, "\n", sprintf("%d families, %d rows, %d counted; %.1f min\n", length(x$rows), nrow(x$census), sum(x$census$counted), as.numeric(x$elapsed)), sep = "")
  print(x$verdict); invisible(x)
}

#' Write a stress-test report
#'
#' Writes a Markdown report with the plan, the base analysis, the per-family
#' summary table, the verdict and the standard figures (census dot plot,
#' bubble swarm, deletion p-value strip, p-value curves where the result has
#' rows with a parameter) as PNG files beside it.
#'
#' @param result A `stress_result` from [run_plan()].
#' @param dir Directory to write into (created if needed). There is no default, so nothing is written unless a location is given.
#' @param name File stem for the report and figures.
#' @param width,height,dpi Figure size in inches and resolution.
#' @param mask_ids Replace subject identifiers with sequence numbers.
#' @return The path of the Markdown file, invisibly.
#' @examples
#' \donttest{
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' plan <- stress_plan(spec, covariance = list(structures = c("cs", "ar1h")), inference = NULL,
#'                     covariates = NULL, weights = FALSE, loo = list(by = "RACE"), permute = NULL,
#'                     reference = NULL, estimator = NULL, fragility = NULL)
#' stress_report(run_plan(plan), dir = tempdir())
#' }
#' @export
stress_report <- function(result, dir, name = "stress_report", width = 9, height = 5, dpi = 150, mask_ids = FALSE) {
  if (!inherits(result, "stress_result")) stop("result must be a stress_result")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  b <- result$base; v <- result$verdict; cen <- result$census
  if (mask_ids) { cen <- ballast::mask_ids(cen, result$plan$spec); v <- stress_verdict(cen, rule = plan_rule(result$plan)) }
  s <- summary(cen)
  md_table <- function(df) { df[] <- lapply(df, function(col) if (is.numeric(col)) format(round(col, 3), trim = TRUE) else as.character(col))
    c(paste("|", paste(names(df), collapse = " | "), "|"), paste("|", paste(rep("---", ncol(df)), collapse = " | "), "|"), apply(df, 1, function(r) paste("|", paste(r, collapse = " | "), "|"))) }
  figs <- character()
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    save_fig <- function(g, stem, w = width, h = height) { f <- file.path(dir, paste0(name, "_", stem, ".png"))
      ok <- tryCatch({ ggplot2::ggsave(f, g, width = w, height = h, dpi = dpi, bg = "white"); TRUE }, error = function(e) FALSE); if (ok) figs[[stem]] <<- basename(f) }
    save_fig(plot(cen), "families")
    if (any(cen$counted & cen$kind == "alternative")) save_fig(plot_swarm(stats::setNames(list(cen), result$plan$spec$label)), "swarm", h = height)
    if (any(cen$counted & cen$kind == "deletion")) save_fig(plot_pstrip(stats::setNames(list(cen), result$plan$spec$label)), "pstrip", h = max(3, 1 + 0.8 * length(unique(cen$family[cen$kind == "deletion"]))))
    crv <- cen[!is.na(cen$param) & !cen$family %in% c("greedy deletion search", "ranked deletion search"), , drop = FALSE]   # the deletion search has its own x (subjects removed)
    if (any(crv$kind == "search")) { g <- plot_pcurve(crv, xlab = "Shift applied to imputed values of the active arm")
      if (length(unique(crv$family)) > 1L) g <- g + ggplot2::facet_wrap(~ family, scales = "free_x"); save_fig(g, "pcurve") }
  }
  fr <- lapply(result$rows, function(r) attr(r, "fragility")); fr <- fr[!vapply(fr, is.null, TRUE)]
  lines <- c(paste("#", result$plan$title), "", sprintf("Generated %s with ballast %s.", format(Sys.time(), "%Y-%m-%d %H:%M"), as.character(utils::packageVersion("ballast"))), "",
             "## Plan", "", paste0("    ", plan_lines(result$plan)), "",
             "## Pre-specified analysis", "", sprintf("Estimate %s (SE %s), 95%% CI %s to %s, p = %s; %d subjects, %d observations.",
                                                      format(b$estimate, digits = 4), format(b$stderr, digits = 3), format(b$lcl, digits = 4), format(b$ucl, digits = 4), format(b$p, digits = 3), b$n_subj, b$n_obs), "",
             "## Verdict", "", sprintf("**%s** over all %d counted rows; **%s** over the %d sensitivity analyses (same estimand)%s.",
                                       toupper(v$stability), v$n_alternatives + v$n_deletions, toupper(v$stability_sensitivity), v$n_sensitivity, if (v$marginal) "; the pre-specified p-value is marginal" else ""),
             sprintf("%d significant, %d crossed alpha, %d outside the pre-specified CI, %d reversed direction; largest shift %s pre-specified SEs.%s", v$n_significant, v$n_crossed, v$n_outside_ci, v$n_reversed, format(v$max_shift_se, digits = 3),
                     if (isTRUE(v$n_diagnostic > 0)) sprintf(" %d diagnostic refit%s fitted and shown (counted = FALSE in the family table) and not counted.", v$n_diagnostic, if (v$n_diagnostic == 1) " was" else "s were") else ""), "",
             if (length(fr)) c(vapply(fr, function(a) sprintf("Smallest subject set that changes %s: %s (%s).", a$target, if (a$reached) sprintf("%d subject%s", a$k, if (a$k == 1) "" else "s") else sprintf("not found within %d removals", length(a$subjects)), paste(a$subjects, collapse = ", ")), ""), ""),
             "## Summary by family", "", md_table(as.data.frame(s)), "",
             if (length(figs)) c("## Figures", "", unlist(lapply(names(figs), function(k) c(sprintf("![%s](%s)", k, figs[[k]]), "")))),
             "## Rows that crossed alpha or left the interval", "",
             if (nrow(v$fragile_rows) || nrow(v$crossed_rows)) md_table(rbind(v$fragile_rows, v$crossed_rows)[, c("family", "label", "role", "estimate", "p", "pct_of_base")]) else "None.")
  f <- file.path(dir, paste0(name, ".md")); writeLines(lines, f)
  invisible(f)
}

## The classification rule of a plan; plans built before 0.7.0 carry none and keep the rule they were written under.
plan_rule <- function(plan) if (is.null(plan$rule)) "interval_or_direction" else plan$rule
plan_rule_text <- function(plan) rule_text(plan_rule(plan))
