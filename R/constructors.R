#' Build a stress spec from a fitted mmrm model
#'
#' Takes the data, response, subject, visit, covariance structure,
#' degrees-of-freedom method and variance estimator from an `mmrm` fit.
#' The treatment variable is the factor that interacts with the visit
#' variable unless given.
#'
#' @param fit An object of class `mmrm`.
#' @param treatment Name of the treatment column; `NULL` finds the factor in
#'   an interaction with the visit variable.
#' @param reference,active,contrast_visit,alpha,weights,label,sas_conventions
#'   As in [stress_spec()].
#' @return A `stress_spec`.
#' @examples
#' fit <- mmrm::mmrm(FEV1 ~ RACE + SEX + FEV1_BL + ARMCD * AVISIT + us(AVISIT | USUBJID),
#'                   data = mmrm::fev_data)
#' stress_spec_mmrm(fit, reference = "PBO")
#' @export
stress_spec_mmrm <- function(fit, treatment = NULL, reference = NULL, active = NULL, contrast_visit = NULL, alpha = 0.05,
                             weights = "equal", label = "pre-specified", sas_conventions = TRUE) {
  if (!inherits(fit, "mmrm")) stop("fit must be an mmrm model")
  d <- fit$data; ff <- stats::formula(fit)
  response <- as.character(ff[[2]]); subject <- mmrm::component(fit, "subject_var"); cov_type <- mmrm::component(fit, "cov_type")
  labs_all <- attr(stats::terms(ff), "term.labels")
  cov_term <- labs_all[grepl("|", labs_all, fixed = TRUE)]; if (length(cov_term) != 1L) stop("cannot find the covariance term in the model formula")
  inner <- substr(cov_term, regexpr("(", cov_term, fixed = TRUE) + 1L, nchar(cov_term) - 1L)
  visit <- all.vars(stats::reformulate(trimws(strsplit(inner, "|", fixed = TRUE)[[1]][1])))[1]
  labs <- labs_all[!grepl("|", labs_all, fixed = TRUE)]
  if (is.null(treatment)) {
    inter <- labs[grepl(":", labs, fixed = TRUE)]
    cand <- unique(unlist(lapply(strsplit(inter, ":", fixed = TRUE), function(p) if (visit %in% p) setdiff(p, visit))))
    cand <- cand[vapply(cand, function(v) is.factor(d[[v]]) || is.character(d[[v]]), TRUE)]
    if (length(cand) != 1L) stop("cannot identify the treatment variable; give `treatment`")
    treatment <- cand
  }
  drop <- labs %in% c(treatment, visit) | vapply(strsplit(labs, ":", fixed = TRUE), function(p) setequal(p, c(treatment, visit)), TRUE)
  covariates <- labs[!drop]
  cov_map <- c(us = "us", ar1 = "ar1", ar1h = "ar1h", cs = "cs", csh = "csh", toep = "toep", toeph = "toeph", ad = "ad", adh = "adh")
  covariance <- cov_map[cov_type]; if (is.na(covariance)) stop("covariance structure ", cov_type, " is not supported by stress_spec")
  if (grepl("/", cov_term, fixed = TRUE)) message("the fit has a grouped covariance; the spec uses the ungrouped structure")
  method <- fit$method; vcov <- fit$vcov
  if (!method %in% DF_METHODS) method <- "Satterthwaite"
  if (!vcov %in% VCOV_TYPES) vcov <- "Asymptotic"
  stress_spec(d, response = response, subject = subject, visit = visit, treatment = treatment, reference = reference, active = active,
              covariates = if (length(covariates)) covariates else NULL, contrast_visit = contrast_visit, covariance = unname(covariance),
              method = method, vcov = vcov, alpha = alpha, weights = weights, label = label, sas_conventions = sas_conventions)
}

#' Build a stress spec from an ADaM basic data structure
#'
#' Subsets a CDISC ADaM BDS data set (ADEFF, ADQS and the like) to one
#' parameter, the analysis-flagged post-baseline records, orders the visits by
#' their numeric code and builds the spec with the baseline value as a
#' covariate by default.
#'
#' @param bds A BDS data frame.
#' @param paramcd The `PARAMCD` value to analyse.
#' @param response Response column, usually `"CHG"` or `"PCHG"`.
#' @param subject,visit,visitn,treatment Column names (`USUBJID`, `AVISIT`,
#'   `AVISITN`, `TRTP` by default).
#' @param reference,active,contrast_visit,covariance,method,vcov,alpha,weights,label
#'   As in [stress_spec()].
#' @param covariates Covariates; the default is the baseline value `BASE`.
#' @param analysis_flag Name of a flag column kept where equal to `"Y"`;
#'   `NULL` keeps all records.
#' @param drop_baseline Drop records flagged `ABLFL == "Y"` or with a
#'   non-positive `visitn`.
#' @param filter Optional function of the data returning the rows to keep,
#'   applied after the other subsets (an analysis-phase restriction, say).
#' @return A `stress_spec`.
#' @examples
#' bds <- transform(mmrm::fev_data, PARAMCD = "FEV1", CHG = FEV1 - FEV1_BL, BASE = FEV1_BL,
#'                  AVISITN = VISITN, TRTP = ARMCD, ANL01FL = "Y")
#' stress_spec_adam(bds, "FEV1", response = "CHG", visit = "AVISIT", reference = "PBO")
#' @export
stress_spec_adam <- function(bds, paramcd, response = "CHG", subject = "USUBJID", visit = "AVISIT", visitn = "AVISITN", treatment = "TRTP",
                             reference = NULL, active = NULL, covariates = ~ BASE, contrast_visit = NULL, analysis_flag = "ANL01FL",
                             drop_baseline = TRUE, filter = NULL, covariance = "us", method = "Kenward-Roger", vcov = "Kenward-Roger-Linear",
                             alpha = 0.05, weights = "equal", label = paste(paramcd, response)) {
  d <- as.data.frame(bds)
  if (!"PARAMCD" %in% names(d)) stop("bds has no PARAMCD column")
  d <- d[d$PARAMCD == paramcd, , drop = FALSE]
  if (!nrow(d)) stop("no records with PARAMCD ", paramcd)
  if (!is.null(analysis_flag)) { if (!analysis_flag %in% names(d)) stop("flag column not in bds: ", analysis_flag); d <- d[!is.na(d[[analysis_flag]]) & d[[analysis_flag]] == "Y", , drop = FALSE] }
  if (drop_baseline) {
    if ("ABLFL" %in% names(d)) d <- d[is.na(d$ABLFL) | d$ABLFL != "Y", , drop = FALSE]
    if (visitn %in% names(d)) d <- d[!is.na(d[[visitn]]) & d[[visitn]] > 0, , drop = FALSE]
  }
  if (!is.null(filter)) { k <- filter(d); d <- d[!is.na(k) & k, , drop = FALSE] }
  if (visitn %in% names(d)) { ord <- unique(d[order(d[[visitn]]), c(visit, visitn)]); d[[visit]] <- factor(as.character(d[[visit]]), levels = unique(as.character(ord[[visit]]))) }
  stress_spec(d, response = response, subject = subject, visit = visit, treatment = treatment, reference = reference, active = active,
              covariates = covariates, contrast_visit = contrast_visit, covariance = covariance, method = method, vcov = vcov,
              alpha = alpha, weights = weights, label = label)
}

#' Perturbation family: the contrast at every visit
#'
#' Fits the pre-specified model once per visit and reports the treatment
#' contrast at each; the contrast at the pre-specified visit is flagged
#' `is_base`. A different visit is a different estimand, so the rows are
#' `role = "supplementary"`.
#'
#' @inheritParams stress_covariance
#' @param visits Visit levels; `NULL` for all.
#' @return A `stress_rows` data frame, one row per visit.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' stress_visits(spec)
#' @export
stress_visits <- function(spec, visits = NULL, cores = 1L) {
  check_spec(spec); force_args()
  if (is.null(visits)) visits <- spec$visit_levels
  if (!all(visits %in% spec$visit_levels)) stop("visits must be visit levels")
  bind_rows_(stress_map(visits, function(v) {
    s <- spec; s$contrast_visit <- v
    stress_fit(s, label = paste("contrast at", v), family = "contrast visit", is_base = identical(v, spec$contrast_visit), role = "supplementary")
  }, cores))
}
