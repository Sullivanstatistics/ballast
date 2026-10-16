#' Assemble a census of perturbations against the base analysis
#'
#' Binds the rows returned by the family functions and scores each against
#' the pre-specified (base) fit: percent of the base estimate, shift in base
#' standard errors, whether the estimate lies inside the base confidence
#' interval, keeps the base direction, is significant at `alpha`, and whether
#' significance changed. Rows that reproduce the base (`is_base`), did not
#' converge, are tipping-point searches, or duplicate an earlier row are not
#' counted.
#'
#' @param spec A [stress_spec()]; the base fit is `stress_fit(spec)`.
#' @param ... `stress_rows` data frames from the family functions.
#' @param base Optional pre-computed base row, to avoid refitting.
#' @return A data frame of class `stress_census` with the family rows plus
#'   `pct_of_base`, `shift_se`, `inside_ci`, `same_direction`, `significant`,
#'   `crossed`, `duplicate` (a later row numerically identical to an earlier
#'   counted row, so the same specification reached by two families), `counted`;
#'   the base row is `attr(, "base")`.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' cen <- stress_census(spec, stress_covariance(spec, c("us", "cs", "ar1h")),
#'                      stress_covariates(spec))
#' summary(cen)
#' stress_verdict(cen)
#' @export
stress_census <- function(spec, ..., base = NULL) {
  if (is.null(base)) base <- stress_fit(spec)
  if (!isTRUE(base$converged)) stop("the base model did not converge")
  rows <- bind_rows_(list(...))
  if (is.null(rows)) stop("no family rows supplied")
  b <- base[1, ]; alpha <- spec$alpha
  rows$pct_of_base <- 100 * rows$estimate / b$estimate
  rows$shift_se <- (rows$estimate - b$estimate) / b$stderr
  rows$inside_ci <- rows$estimate >= b$lcl & rows$estimate <= b$ucl
  rows$same_direction <- sign(rows$estimate) == sign(b$estimate)
  rows$significant <- rows$p < alpha
  rows$crossed <- rows$significant != (b$p < alpha)
  # a specification reached by two families (the grid and the covariance panel, say) is one alternative: later rows whose
  # estimate, SE, df and observation count repeat an earlier counted row to 1e-9 are flagged duplicate and not counted
  key <- paste(signif(rows$estimate, 10), signif(rows$stderr, 10), signif(rows$df, 10), rows$n_obs, rows$kind)
  rows$duplicate <- !rows$is_base & rows$converged & duplicated(key)
  rows$counted <- !rows$is_base & rows$converged & rows$kind != "search" & !rows$duplicate
  structure(rows, class = c("stress_census", "data.frame"), base = b, alpha = alpha, treatment_levels = spec$treatment_levels, arms = c(spec$reference, spec$active))
}

#' Summarise a census by family
#'
#' @param object A `stress_census`.
#' @param ... Unused.
#' @return A data frame with one row per family, kind and role: counted analyses,
#'   number significant, number that crossed `alpha`, number outside the base
#'   confidence interval, number reversing direction, the range of percent of
#'   base, and the largest shift in base standard errors. Closing rows total
#'   the sensitivity analyses (same estimand) and all counted rows.
#' @export
summary.stress_census <- function(object, ...) {
  x <- as.data.frame(object)[object$counted, , drop = FALSE]
  one <- function(z, family, kind) data.frame(
    family = family, kind = kind, n = nrow(z), significant = sum(z$significant, na.rm = TRUE), crossed = sum(z$crossed, na.rm = TRUE),
    outside_ci = sum(!z$inside_ci, na.rm = TRUE), reversed = sum(!z$same_direction, na.rm = TRUE),
    pct_min = if (any(!is.na(z$pct_of_base))) min(z$pct_of_base, na.rm = TRUE) else NA_real_,
    pct_max = if (any(!is.na(z$pct_of_base))) max(z$pct_of_base, na.rm = TRUE) else NA_real_,
    max_shift_se = if (any(!is.na(z$shift_se))) max(abs(z$shift_se), na.rm = TRUE) else NA_real_, stringsAsFactors = FALSE)
  keys <- unique(x[, c("family", "kind", "role")])
  out <- do.call(rbind, lapply(seq_len(nrow(keys)), function(i) {
    z <- x[x$family == keys$family[i] & x$kind == keys$kind[i] & x$role == keys$role[i], , drop = FALSE]
    cbind(one(z, keys$family[i], keys$kind[i]), role = keys$role[i], stringsAsFactors = FALSE) }))
  out <- rbind(out, cbind(one(x[x$role == "sensitivity", , drop = FALSE], "All sensitivity", "all"), role = "sensitivity", stringsAsFactors = FALSE),
               cbind(one(x, "All", "all"), role = "all", stringsAsFactors = FALSE))
  rownames(out) <- NULL
  structure(out, class = c("summary.stress_census", "data.frame"), base = attr(object, "base"), alpha = attr(object, "alpha"))
}

#' @export
print.summary.stress_census <- function(x, digits = 3, ...) {
  b <- attr(x, "base")
  cat(sprintf("Base analysis: estimate %s (SE %s), 95%% CI %s to %s, p = %s\n", format(b$estimate, digits = digits), format(b$stderr, digits = digits),
              format(b$lcl, digits = digits), format(b$ucl, digits = digits), format(b$p, digits = digits)))
  y <- as.data.frame(x); y$pct_min <- round(y$pct_min); y$pct_max <- round(y$pct_max); y$max_shift_se <- round(y$max_shift_se, 2)
  print(y, row.names = FALSE, ...)
  invisible(x)
}

#' Classify the census: robust, sensitive or fragile, and marginal
#'
#' Applies the definitions: *fragile* if any counted row reverses the base
#' direction or lies outside the base confidence interval; otherwise
#' *sensitive* if any counted row changes significance at `alpha`; otherwise
#' *robust*. *Marginal* is a separate flag on the base p-value, true when it
#' lies within `alpha * marginal_band`.
#'
#' @param census A `stress_census`.
#' @param marginal_band Multiplicative band around `alpha` for the marginal
#'   flag; the default flags a base p between `alpha / 2` and `2 * alpha`.
#' @return A list of class `stress_verdict`: `stability` over every counted
#'   row, `stability_sensitivity` over the rows that keep the estimand
#'   (`role = "sensitivity"`), `marginal`, the counts behind them, and the rows
#'   that drove the classification.
#' @export
stress_verdict <- function(census, marginal_band = c(0.5, 2)) {
  b <- attr(census, "base"); alpha <- attr(census, "alpha")
  x <- as.data.frame(census)[census$counted, , drop = FALSE]
  fragile_rows <- x[!is.na(x$estimate) & (!x$inside_ci | !x$same_direction), , drop = FALSE]
  crossed_rows <- x[!is.na(x$p) & x$crossed, , drop = FALSE]
  stability <- if (nrow(fragile_rows)) "fragile" else if (nrow(crossed_rows)) "sensitive" else "robust"
  xs <- x[x$role == "sensitivity", , drop = FALSE]
  stability_sensitivity <- if (any(!xs$inside_ci | !xs$same_direction, na.rm = TRUE)) "fragile" else if (any(xs$crossed, na.rm = TRUE)) "sensitive" else "robust"
  marginal <- b$p >= alpha * marginal_band[1] & b$p <= alpha * marginal_band[2]
  structure(list(stability = stability, stability_sensitivity = stability_sensitivity, marginal = marginal, base = b, alpha = alpha,
                 n_sensitivity = nrow(xs), n_supplementary = nrow(x) - nrow(xs),
                 n_alternatives = sum(x$kind == "alternative"), n_deletions = sum(x$kind == "deletion"),
                 n_significant = sum(x$significant, na.rm = TRUE), n_crossed = nrow(crossed_rows),
                 n_outside_ci = sum(!x$inside_ci, na.rm = TRUE), n_reversed = sum(!x$same_direction, na.rm = TRUE),
                 max_shift_se = if (nrow(x)) max(abs(x$shift_se), na.rm = TRUE) else NA_real_,
                 fragile_rows = fragile_rows, crossed_rows = crossed_rows), class = "stress_verdict")
}

#' @export
print.stress_verdict <- function(x, digits = 3, ...) {
  b <- x$base
  cat(sprintf("Base: estimate %s, 95%% CI %s to %s, p = %s (alpha %s)\n", format(b$estimate, digits = digits), format(b$lcl, digits = digits),
              format(b$ucl, digits = digits), format(b$p, digits = digits), format(x$alpha)))
  cat(sprintf("Counted: %d alternative analyses, %d deletions; %d significant, %d crossed alpha\n", x$n_alternatives, x$n_deletions, x$n_significant, x$n_crossed))
  cat(sprintf("Outside base CI: %d; direction reversed: %d; largest shift: %s base SE\n", x$n_outside_ci, x$n_reversed, format(x$max_shift_se, digits = digits)))
  cat(sprintf("Verdict: %s over all counted rows; %s over the %d sensitivity analyses (same estimand; %d supplementary rows)%s\n",
              toupper(x$stability), toupper(x$stability_sensitivity), x$n_sensitivity, x$n_supplementary, if (x$marginal) "; marginal: base p near alpha" else ""))
  if (nrow(x$fragile_rows)) { cat("Rows outside the CI or reversed:\n"); print(x$fragile_rows[, c("family", "label", "estimate", "p")], row.names = FALSE, digits = digits) }
  else if (nrow(x$crossed_rows)) { cat("Rows that crossed alpha:\n"); print(utils::head(x$crossed_rows[, c("family", "label", "estimate", "p")], 10), row.names = FALSE, digits = digits) }
  invisible(x)
}
