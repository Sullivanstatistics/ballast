#' Define the pre-specified MMRM to stress-test
#'
#' A `stress_spec` holds the analysis data and every decision of the
#' pre-specified mixed model for repeated measures: the response, subject,
#' visit and treatment variables, the covariates, the visit at which the
#' treatment contrast is taken, the within-subject covariance structure, the
#' degrees-of-freedom method, the variance estimator and the significance
#' level. Every family function in the package takes a spec and returns rows in
#' the schema of [stress_fit()].
#'
#' The fixed effects are `covariates + treatment + visit + treatment:visit`;
#' the treatment contrast at `contrast_visit` is the difference of
#' least-squares means (active minus reference) with class covariates weighted
#' equally over their levels and continuous covariates at their means, the
#' convention of SAS `LSMEANS`.
#'
#' @param data A data frame in long format, one row per subject and visit.
#' @param response Name of the response column (change from baseline, say).
#' @param subject Name of the subject identifier column.
#' @param visit Name of the visit column; coerced to a factor whose level order
#'   is the visit order.
#' @param treatment Name of the treatment column (two or more arms).
#' @param reference The reference (control) level of `treatment`. Defaults to
#'   the first factor level.
#' @param active The treatment level compared with the reference. Defaults to
#'   the first non-reference level. With three or more arms, change it with
#'   [spec_update()] to stress-test each comparison in turn.
#' @param covariates Fixed-effect covariates besides treatment and visit, as a
#'   one-sided formula (`~ base + site`) or a character vector of term labels.
#'   Character and logical columns are treated as class variables.
#' @param contrast_visit The visit level at which the treatment contrast is
#'   estimated. Defaults to the last visit level.
#' @param covariance Covariance structure name as used by `mmrm`: `"us"`,
#'   `"ar1"`, `"ar1h"`, `"cs"`, `"csh"`, `"toep"`, `"toeph"`, `"ad"`, `"adh"`, or
#'   `"sp_exp"` (spatial exponential, the SAS `SP(POW)` structure, on the
#'   continuous `time` variable).
#' @param time Name of a numeric time column for the `"sp_exp"` structure (days
#'   from randomisation, say; mmrm converges more readily with time rescaled to
#'   hundreds of days).
#' @param method Degrees-of-freedom method passed to [mmrm::mmrm_control()]:
#'   `"Satterthwaite"`, `"Kenward-Roger"`, `"Residual"` or `"Between-Within"`.
#' @param vcov Variance estimator passed to [mmrm::mmrm_control()]:
#'   `"Asymptotic"`, `"Empirical"`, `"Empirical-Jackknife"`,
#'   `"Empirical-Bias-Reduced"`, `"Kenward-Roger"` or
#'   `"Kenward-Roger-Linear"`. The SAS `DDFM=KR` default corresponds to
#'   `method = "Kenward-Roger"` with `vcov = "Kenward-Roger-Linear"`.
#' @param alpha Two-sided significance level.
#' @param weights How class covariates are weighted in the least-squares means:
#'   `"equal"` (every level equally, SAS `LSMEANS` default) or `"observed"`
#'   (the design is averaged over the covariate values of the analysis rows,
#'   as SAS `OBSMARGINS` and g-computation do).
#' @param label Label for the base analysis in output rows.
#' @param sas_conventions If `TRUE`, the between-within degrees of freedom for
#'   a sandwich-variance contrast are computed as SAS `PROC MIXED` does when
#'   `EMPIRICAL` is combined with a `DDFM` it cannot honour (observations minus
#'   subjects minus the rank of the within-subject design columns).
#'
#' @return An object of class `stress_spec`.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, response = "FEV1", subject = "USUBJID",
#'                     visit = "AVISIT", treatment = "ARMCD", reference = "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL, contrast_visit = "VIS4")
#' spec
#' @export
stress_spec <- function(data, response, subject, visit, treatment, reference = NULL, active = NULL,
                        covariates = NULL, contrast_visit = NULL, covariance = "us",
                        method = "Kenward-Roger", vcov = "Kenward-Roger-Linear",
                        alpha = 0.05, weights = c("equal", "observed"), label = "pre-specified", sas_conventions = TRUE, time = NULL) {
  weights <- match.arg(weights)
  if (covariance == "sp_exp" && (is.null(time) || !time %in% names(data))) stop("the sp_exp structure needs a numeric `time` column")
  data <- as.data.frame(data)
  need <- c(response, subject, visit, treatment)
  if (!all(need %in% names(data))) stop("columns not in data: ", paste(setdiff(need, names(data)), collapse = ", "))
  covs <- parse_covariates(covariates)
  cov_vars <- if (length(covs)) all.vars(stats::reformulate(covs)) else character()
  if (!all(cov_vars %in% names(data))) stop("covariate columns not in data: ", paste(setdiff(cov_vars, names(data)), collapse = ", "))
  covariance <- match.arg(covariance, COV_STRUCTURES)
  method <- match.arg(method, DF_METHODS)
  vcov <- match.arg(vcov, VCOV_TYPES)
  spec <- structure(list(data = NULL, response = response, subject = subject, visit = visit, treatment = treatment,
                         reference = reference, active = active, covariates = covs, cov_vars = cov_vars, contrast_visit = NULL,
                         covariance = covariance, method = method, vcov = vcov, alpha = alpha, weights = weights, label = label,
                         sas_conventions = sas_conventions, time = time, visit_levels = NULL, treatment_levels = NULL),
                    class = "stress_spec")
  data <- conform_data(spec, data, first = TRUE)
  spec$data <- data
  spec$visit_levels <- levels(data[[visit]]); spec$treatment_levels <- levels(data[[treatment]])
  spec$reference <- spec$treatment_levels[1]
  if (is.null(active)) active <- spec$treatment_levels[2]
  active <- as.character(active)
  if (!active %in% spec$treatment_levels || active == spec$reference) stop("active must be a treatment level other than the reference")
  spec$active <- active
  if (is.null(contrast_visit)) contrast_visit <- utils::tail(spec$visit_levels, 1)
  contrast_visit <- as.character(contrast_visit)
  if (!contrast_visit %in% spec$visit_levels) stop("contrast_visit ", contrast_visit, " is not a level of ", visit)
  spec$contrast_visit <- contrast_visit
  spec
}

COV_STRUCTURES <- c("us", "ar1", "ar1h", "cs", "csh", "toep", "toeph", "ad", "adh", "sp_exp")
DF_METHODS <- c("Satterthwaite", "Kenward-Roger", "Residual", "Between-Within")
VCOV_TYPES <- c("Asymptotic", "Empirical", "Empirical-Jackknife", "Empirical-Bias-Reduced", "Kenward-Roger", "Kenward-Roger-Linear")

parse_covariates <- function(covariates) {
  if (is.null(covariates)) character()
  else if (inherits(covariates, "formula")) attr(stats::terms(covariates), "term.labels")
  else as.character(covariates)
}

# Apply the spec's factor conventions to a (possibly alternative) data set.
conform_data <- function(spec, data, first = FALSE) {
  data <- as.data.frame(data)
  data[[spec$subject]] <- factor(as.character(data[[spec$subject]]))
  if (first) {
    data[[spec$visit]] <- if (is.factor(data[[spec$visit]])) droplevels(data[[spec$visit]]) else factor(data[[spec$visit]], levels = sort(unique(data[[spec$visit]])))
    data[[spec$treatment]] <- if (is.factor(data[[spec$treatment]])) droplevels(data[[spec$treatment]]) else factor(data[[spec$treatment]])
    if (!is.null(spec$reference)) data[[spec$treatment]] <- stats::relevel(data[[spec$treatment]], ref = as.character(spec$reference))
    if (nlevels(data[[spec$treatment]]) < 2L) stop("treatment must have at least two levels")
  } else {
    data[[spec$visit]] <- factor(as.character(data[[spec$visit]]), levels = union(spec$visit_levels, unique(as.character(data[[spec$visit]]))))
    data[[spec$treatment]] <- factor(as.character(data[[spec$treatment]]), levels = spec$treatment_levels)
    if (anyNA(data[[spec$treatment]])) stop("alternative data has treatment levels outside the spec's levels")
  }
  for (v in spec$cov_vars) if (is.character(data[[v]]) || is.logical(data[[v]])) data[[v]] <- factor(data[[v]])
  data[order(data[[spec$subject]], data[[spec$visit]]), , drop = FALSE]
}

#' Modify a stress spec
#'
#' Returns a copy of `spec` with the named settings replaced. Settings that
#' change the data conventions (`reference`, `visit`, `treatment`, `subject`,
#' `response`) cannot be changed here; build a new spec instead.
#'
#' @param spec A `stress_spec`.
#' @param ... Settings to replace: `covariance`, `method`, `vcov`,
#'   `covariates`, `contrast_visit`, `alpha`, `label`, `data`, `weights`, `active`.
#' @return The modified `stress_spec`.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' spec_update(spec, covariance = "ar1h", method = "Satterthwaite", vcov = "Asymptotic")
#' @export
spec_update <- function(spec, ...) {
  new <- list(...)
  bad <- setdiff(names(new), c("covariance", "method", "vcov", "covariates", "contrast_visit", "alpha", "label", "data", "weights", "active", "time"))
  if (!is.null(new$active)) { new$active <- as.character(new$active); if (!new$active %in% spec$treatment_levels || new$active == spec$reference) stop("active must be a treatment level other than the reference") }
  if (!is.null(new$contrast_visit)) { new$contrast_visit <- as.character(new$contrast_visit); if (!new$contrast_visit %in% spec$visit_levels) stop("contrast_visit is not a visit level") }
  if (!is.null(new$weights)) new$weights <- match.arg(new$weights, c("equal", "observed"))
  if (length(bad)) stop("cannot update: ", paste(bad, collapse = ", "))
  if ("covariates" %in% names(new)) {
    new$covariates <- parse_covariates(new$covariates)
    spec$cov_vars <- if (length(new$covariates)) all.vars(stats::reformulate(new$covariates)) else character()
  }
  if (!is.null(new$data)) new$data <- conform_data(spec, new$data)
  if (!is.null(new$covariance)) new$covariance <- match.arg(new$covariance, COV_STRUCTURES)
  if (!is.null(new$method)) new$method <- match.arg(new$method, DF_METHODS)
  if (!is.null(new$vcov)) new$vcov <- match.arg(new$vcov, VCOV_TYPES)
  for (n in names(new)) spec[[n]] <- new[[n]]
  spec
}

#' @export
print.stress_spec <- function(x, ...) {
  cat("<stress_spec> ", x$label, "\n", sep = "")
  cat("  data:       ", nrow(x$data), " rows, ", nlevels(x$data[[x$subject]]), " subjects, visits ",
      paste(x$visit_levels, collapse = " "), "\n", sep = "")
  cat("  model:      ", deparse1(build_formula(x)), "\n", sep = "")
  cat("  contrast:   ", x$active, " - ", x$reference, " at ", x$contrast_visit, if (length(x$treatment_levels) > 2L) sprintf("  (arms: %s)", paste(x$treatment_levels, collapse = ", ")) else "", "\n", sep = "")
  cat("  inference:  ", x$method, " df, ", x$vcov, " vcov, alpha ", x$alpha, "\n", sep = "")
  invisible(x)
}

# Model formula for mmrm from a spec (optionally with a different covariate set / covariance).
build_formula <- function(spec, covariates = spec$covariates, covariance = spec$covariance) {
  cov_term <- if (identical(covariance, "sp_exp")) { if (is.null(spec$time)) stop("the sp_exp structure needs `time` in the spec"); paste0("sp_exp(", spec$time, " | ", spec$subject, ")") }
              else paste0(covariance, "(", spec$visit, " | ", spec$subject, ")")
  rhs <- c(covariates, spec$treatment, spec$visit, paste0(spec$treatment, ":", spec$visit), cov_term)
  stats::as.formula(paste(spec$response, "~", paste(rhs, collapse = " + ")), env = globalenv())
}
