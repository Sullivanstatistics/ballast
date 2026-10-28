#' Write regulatory-style tables and the census
#'
#' Writes the per-family summary, the rows that crossed alpha or left the
#' interval, the deletion-search path and the full census. CSV files are
#' always written; with `flextable` and `officer` installed, a Word document
#' with the tables in a standard clinical-report layout is written too, and
#' an RTF version of each table.
#'
#' @param result A `stress_result` from [run_plan()].
#' @param dir Directory to write into (created if needed). There is no default, so nothing is written unless a location is given.
#' @param name File stem.
#' @param formats Any of `"csv"`, `"docx"`, `"rtf"`.
#' @param digits Decimal places in the formatted tables.
#' @param mask_ids Replace subject identifiers with sequence numbers.
#' @return The paths written, invisibly.
#' @examples
#' \donttest{
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' plan <- stress_plan(spec, covariance = list(structures = c("cs", "ar1h")), inference = NULL,
#'                     covariates = NULL, weights = FALSE, loo = list(by = "RACE"), permute = NULL,
#'                     reference = NULL, estimator = NULL, fragility = NULL)
#' stress_tables(run_plan(plan), dir = tempdir(), formats = "csv")
#' }
#' @export
stress_tables <- function(result, dir, name = "stress", formats = c("csv", "docx", "rtf"), digits = 3, mask_ids = FALSE) {
  if (!inherits(result, "stress_result")) stop("result must be a stress_result")
  formats <- match.arg(formats, c("csv", "docx", "rtf"), several.ok = TRUE)
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  cen <- result$census; v <- result$verdict; b <- result$base
  if (mask_ids) { cen <- ballast::mask_ids(cen, result$plan$spec); v <- stress_verdict(cen, rule = plan_rule(result$plan)) }
  fmt <- function(x, d = digits) ifelse(is.na(x), "", formatC(x, digits = d, format = "f"))
  fp <- function(p) ifelse(is.na(p), "", ifelse(p < 0.001, "<0.001", formatC(p, digits = 3, format = "f")))
  s <- as.data.frame(summary(cen))
  t1 <- data.frame("Family" = s$family, "Kind" = s$kind, "Role" = s$role, "Counted" = ifelse(s$counted, "yes", "no"), "Analyses" = s$n, "Significant" = s$significant, "Crossed alpha" = s$crossed,
                   "Outside CI" = s$outside_ci, "Reversed" = s$reversed, "% of pre-specified, range" = ifelse(is.na(s$pct_min), "", paste0(round(s$pct_min), " to ", round(s$pct_max))),
                   "Largest shift (SE)" = fmt(s$max_shift_se, 2), check.names = FALSE, stringsAsFactors = FALSE)
  x <- as.data.frame(cen)[cen$counted & !is.na(cen$estimate), , drop = FALSE]
  cr <- x[(!is.na(x$crossed) & x$crossed) | !x$inside_ci | !x$same_direction, , drop = FALSE]
  ci_txt <- function(l, u) if (length(l)) paste0(fmt(l), " to ", fmt(u)) else character()
  t2 <- data.frame("Family" = cr$family, "Analysis" = cr$label, "Role" = cr$role, "Estimate" = fmt(cr$estimate), "SE" = fmt(cr$stderr),
                   "95% CI" = ci_txt(cr$lcl, cr$ucl), "p" = fp(cr$p), "% of pre-specified" = round(cr$pct_of_base), check.names = FALSE, stringsAsFactors = FALSE)
  if (!nrow(t2)) t2 <- data.frame("Family" = "None", "Analysis" = "No counted analysis crossed alpha, left the interval or reversed direction", "Role" = "", "Estimate" = "", "SE" = "", "95% CI" = "", "p" = "", "% of pre-specified" = NA, check.names = FALSE, stringsAsFactors = FALSE)
  t3 <- NULL; fr <- result$rows$fragility
  if (!is.null(fr) && mask_ids) fr <- ballast::mask_ids(fr, result$plan$spec)
  if (!is.null(fr)) { a <- attr(fr, "fragility")
    t3 <- data.frame("Removed" = fr$param, "Subject added" = sub("step [0-9]+ removed ", "", fr$note), "Estimate" = fmt(fr$estimate), "95% CI" = ci_txt(fr$lcl, fr$ucl), "p" = fp(fr$p), check.names = FALSE, stringsAsFactors = FALSE) }
  census_out <- as.data.frame(cen); census_out$pct_of_base <- round(census_out$pct_of_base, 1)
  header <- sprintf("Pre-specified analysis: %s minus %s at %s: estimate %s (SE %s), 95%% CI %s to %s, p %s. Verdict: %s (sensitivity analyses: %s)%s.%s",
                    result$plan$spec$active, result$plan$spec$reference, result$plan$spec$contrast_visit, fmt(b$estimate), fmt(b$stderr), fmt(b$lcl), fmt(b$ucl), fp(b$p),
                    v$stability, v$stability_sensitivity, if (v$marginal) "; marginal" else "", if (v$n_failed > 0) sprintf(" %d of %d refits did not converge and are not counted.", v$n_failed, v$n_rows) else "")
  footer <- "Counting rule: rows reproducing the pre-specified analysis and duplicate specifications are not counted; tipping-point grids are searches; diagnostic refits (Counted = no) are fitted and shown but do not enter the verdict. Shift in SE: |estimate minus pre-specified| / pre-specified SE."
  paths <- character()
  if ("csv" %in% formats) {
    for (nm in c("summary", "crossings", "census", if (!is.null(t3)) "fragility")) {
      obj <- switch(nm, summary = t1, crossings = t2, census = census_out, fragility = t3)
      f <- file.path(dir, sprintf("%s_%s.csv", name, nm)); utils::write.csv(obj, f, row.names = FALSE); paths <- c(paths, f) }
  }
  if (any(c("docx", "rtf") %in% formats)) {
    if (!requireNamespace("flextable", quietly = TRUE) || !requireNamespace("officer", quietly = TRUE)) warning("flextable and officer are needed for docx and rtf output; CSV written only")
    else {
      ft <- function(df, title) { f <- flextable::flextable(df); f <- flextable::set_caption(f, title); f <- flextable::fontsize(f, size = 9, part = "all")
        f <- flextable::font(f, fontname = "Arial", part = "all"); f <- flextable::autofit(f); flextable::add_footer_lines(f, footer) }
      tabs <- list(list(df = t1, title = "Table 1. Stress test summary by family"), list(df = t2, title = "Table 2. Analyses that crossed alpha, left the pre-specified interval or reversed direction"))
      if (!is.null(t3)) tabs[[3]] <- list(df = t3, title = sprintf("Table 3. Greedy deletion search (%s)", attr(fr, "fragility")$target))
      if ("docx" %in% formats) {
        doc <- officer::read_docx(); doc <- officer::body_add_par(doc, result$plan$title, style = "heading 1"); doc <- officer::body_add_par(doc, header)
        for (tb in tabs) { doc <- officer::body_add_par(doc, ""); doc <- flextable::body_add_flextable(doc, ft(tb$df, tb$title)) }
        f <- file.path(dir, paste0(name, "_tables.docx")); print(doc, target = f); paths <- c(paths, f)
      }
      if ("rtf" %in% formats) for (i in seq_along(tabs)) { f <- file.path(dir, sprintf("%s_table%d.rtf", name, i)); flextable::save_as_rtf(ft(tabs[[i]]$df, tabs[[i]]$title), path = f); paths <- c(paths, f) }
    }
  }
  invisible(paths)
}

#' Write the run log for an audit trail
#'
#' Records the plan text and its MD5 hash, the seed, the package and R
#' versions, the platform, the elapsed time and the verdict, as JSON if
#' `jsonlite` is installed and as plain text otherwise. The hash of the plan
#' text lets a reviewer confirm that the stress test run is the one that was
#' pre-specified.
#'
#' @param result A `stress_result`.
#' @param file Path to write; `NULL` returns the log without writing.
#' @param seed The seed that was passed to [run_plan()].
#' @return The log as a list, invisibly.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' plan <- stress_plan(spec, covariance = list(structures = c("cs", "ar1h")), inference = NULL,
#'                     covariates = NULL, weights = FALSE, loo = NULL, permute = NULL,
#'                     reference = NULL, estimator = NULL, fragility = NULL)
#' str(stress_log(run_plan(plan)))
#' @export
stress_log <- function(result, file = NULL, seed = 1) {
  if (!inherits(result, "stress_result")) stop("result must be a stress_result")
  txt <- plan_lines(result$plan); tf <- tempfile(); writeLines(txt, tf); h <- unname(tools::md5sum(tf)); unlink(tf)
  v <- result$verdict; s <- result$plan$spec
  log <- list(title = result$plan$title, plan_md5 = h, plan = txt, run_time = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), seed = seed,
              elapsed_min = round(as.numeric(result$elapsed), 2), r_version = R.version.string, ballast = as.character(utils::packageVersion("ballast")),
              mmrm = as.character(utils::packageVersion("mmrm")), platform = R.version$platform,
              data = list(subjects = nlevels(s$data[[s$subject]]), rows = nrow(s$data), response = s$response, arms = s$treatment_levels),
              families = names(result$rows), rows = nrow(result$census), counted = sum(result$census$counted),
              verdict = list(stability = v$stability, stability_sensitivity = v$stability_sensitivity, marginal = v$marginal, crossed = v$n_crossed, outside_ci = v$n_outside_ci, reversed = v$n_reversed))
  if (!is.null(file)) {
    if (requireNamespace("jsonlite", quietly = TRUE)) jsonlite::write_json(log, file, pretty = TRUE, auto_unbox = TRUE)
    else writeLines(c(paste0(names(log), ": ", vapply(log, function(x) paste(format(unlist(x)), collapse = " | "), ""))), file)
  }
  invisible(log)
}
