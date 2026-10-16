#' Explain why an alternative analysis moved
#'
#' For one row of a census (an alternative that crossed alpha, say),
#' attributes the difference between its estimate and the pre-specified
#' estimate to subjects. Each subject's influence is the change in the
#' contrast when that subject is removed, computed under the pre-specified
#' settings and again under the alternative's settings; the difference of the
#' two influences says how much more (or less) that subject drives the result
#' under the alternative. Subjects are ranked by the absolute difference.
#'
#' The alternative's model settings are read from the row (`covariance`,
#' `method`, `vcov`, `covariates`). For an alternative that used different
#' data, pass that data as `data`.
#'
#' @inheritParams stress_covariance
#' @param row One row of a `stress_census` or `stress_rows` data frame.
#' @param data The alternative's data set, if it differs from the spec's.
#' @param top Number of subjects to print.
#' @return A data frame of class `stress_explanation` with one row per
#'   subject: `subject`, `arm`, `n_visits`, `infl_base`, `infl_alt`,
#'   `difference`, sorted by absolute difference; the row explained is
#'   `attr(, "row")` and the two full-data estimates are `attr(, "estimates")`.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:30), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' cen <- stress_census(spec, stress_covariates(spec))
#' stress_explain(spec, cen[1, ], top = 5)
#' @export
stress_explain <- function(spec, row, data = NULL, top = 10, cores = 1L) {
  check_spec(spec); force_args()
  row <- as.data.frame(row)[1, , drop = FALSE]
  covs <- if (nzchar(row$covariates)) trimws(strsplit(row$covariates, "+", fixed = TRUE)[[1]]) else character()
  alt <- list(covariance = row$covariance, method = row$method, vcov = row$vcov, covariates = covs)
  if (!alt$covariance %in% COV_STRUCTURES || !alt$method %in% DF_METHODS || !alt$vcov %in% VCOV_TYPES)
    stop("the row's settings cannot be refitted (an estimator-class or imputation row); explain a model-family row")
  d_base <- spec$data; d_alt <- if (is.null(data)) d_base else conform_data(spec, data)
  sub <- spec$subject
  fit_alt <- function(d) stress_fit(spec, data = d, covariance = alt$covariance, method = alt$method, vcov = alt$vcov, covariates = alt$covariates)
  e_base <- stress_fit(spec)$estimate; e_alt <- fit_alt(d_alt)$estimate
  subjects <- union(levels(d_base[[sub]]), levels(d_alt[[sub]]))
  infl <- stress_map(subjects, function(u) c(
    base = e_base - stress_fit(spec, data = d_base[d_base[[sub]] != u, , drop = FALSE])$estimate,
    alt = e_alt - fit_alt(d_alt[d_alt[[sub]] != u, , drop = FALSE])$estimate), cores)
  m <- do.call(rbind, infl)
  arm <- vapply(subjects, function(u) as.character(d_base[[spec$treatment]][match(u, as.character(d_base[[sub]]))]), "")
  nv <- vapply(subjects, function(u) sum(as.character(d_base[[sub]]) == u & !is.na(d_base[[spec$response]])), 0L)
  out <- data.frame(subject = subjects, arm = arm, n_visits = nv, infl_base = m[, "base"], infl_alt = m[, "alt"], difference = m[, "alt"] - m[, "base"], stringsAsFactors = FALSE)
  out <- out[order(-abs(out$difference)), ]; rownames(out) <- NULL
  structure(out, class = c("stress_explanation", "data.frame"), row = row, estimates = c(base = e_base, alternative = e_alt), top = top)
}

#' @export
print.stress_explanation <- function(x, ...) {
  r <- attr(x, "row"); e <- attr(x, "estimates")
  cat(sprintf("Alternative: %s / %s\n", r$family, r$label))
  cat(sprintf("Estimate %s (pre-specified) -> %s (alternative); shift %s\n", format(e[["base"]], digits = 4), format(e[["alternative"]], digits = 4), format(e[["alternative"]] - e[["base"]], digits = 3)))
  cat(sprintf("Subjects whose influence changes most (influence = estimate minus estimate without the subject):\n"))
  print(utils::head(as.data.frame(x), attr(x, "top")), row.names = FALSE, digits = 3)
  invisible(x)
}
