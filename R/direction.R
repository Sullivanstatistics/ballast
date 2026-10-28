#' Direction stability of a result that misses significance
#'
#' A small trial can carry a real effect and still miss significance for want
#' of power. For such a result the stress test reports how stable what was
#' seen is: how many pre-specified re-analyses reverse the direction of the
#' estimate, and which; how many move it outside the filed confidence
#' interval; and how many participants the greedy deletion search removes
#' before the direction reverses.
#'
#' @param spec A [stress_spec()].
#' @param census Optional `stress_census` over the pre-specified re-analyses.
#'   If given, its counted rows supply the reversal and interval counts;
#'   without it only the deletion count is computed.
#' @param max_k Most participants to remove in the deletion search
#'   ([stress_fragility()] with `target = "direction"`). The default is 10.
#' @param method `"ranked"` (default) or `"greedy"`, as in [stress_fragility()].
#' @param cores Passed to [stress_fragility()].
#' @return A list of class `stress_direction`: `base` (the pre-specified fit),
#'   `z`, `n`, `significant`, `alpha`; from the census `n_counted`,
#'   `n_reversed`, `n_outside_ci` and `reversed_rows` (`NA` and `NULL` without
#'   one); from the search `k_rev` (participants removed to reverse, `NA` if
#'   not reached within `max_k`), `k_rev_reached`, `subjects`, `share_of_n`
#'   and `search`, the rows of the search.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' cen <- stress_census(spec, stress_covariance(spec, c("cs", "ar1h")), stress_covariates(spec))
#' stress_direction(spec, cen, max_k = 6)
#' @seealso [stress_verdict()] for the summary label, [stress_fragility()] for
#'   the deletion searches.
#' @export
stress_direction <- function(spec, census = NULL, max_k = 10L, method = c("ranked", "greedy"), cores = 1L) {
  check_spec(spec); force_args(); method <- match.arg(method)
  base <- stress_fit(spec); if (!isTRUE(base$converged)) stop("the base model did not converge")
  z <- base$estimate / base$stderr; n <- base$n_subj
  search <- stress_fragility(spec, target = "direction", max_k = max_k, method = method, cores = cores)
  a <- attr(search, "fragility")
  n_counted <- NA_integer_; n_reversed <- NA_integer_; n_outside <- NA_integer_; reversed_rows <- NULL
  if (!is.null(census)) {
    if (!inherits(census, "stress_census")) stop("census must be a stress_census")
    x <- as.data.frame(census)[census$counted & !is.na(census$estimate), , drop = FALSE]
    n_counted <- nrow(x); n_reversed <- sum(!x$same_direction); n_outside <- sum(!x$inside_ci)
    reversed_rows <- x[!x$same_direction, c("family", "label", "estimate", "p"), drop = FALSE]
  }
  structure(list(base = base, z = z, n = n, significant = base$p < spec$alpha, alpha = spec$alpha,
                 n_counted = n_counted, n_reversed = n_reversed, n_outside_ci = n_outside, reversed_rows = reversed_rows,
                 k_rev = a$k, k_rev_reached = a$reached, max_k = max_k, method = method, subjects = a$subjects,
                 share_of_n = if (a$reached) a$k / n else NA_real_, search = search), class = "stress_direction")
}

#' @export
print.stress_direction <- function(x, digits = 3, ...) {
  b <- x$base
  cat("Direction stability\n")
  cat(sprintf("Base: estimate %s, %s%% CI %s to %s, p = %s (z = %s); %s at alpha %s\n", format(b$estimate, digits = digits),
              format(100 * (1 - x$alpha)), format(b$lcl, digits = digits), format(b$ucl, digits = digits), format(b$p, digits = digits),
              format(x$z, digits = digits), if (x$significant) "significant" else "not significant", format(x$alpha)))
  if (!is.na(x$n_counted)) {
    cat(sprintf("Pre-specified re-analyses: %d of %d reverse the direction; %d move the estimate outside the filed interval\n",
                x$n_reversed, x$n_counted, x$n_outside_ci))
    if (x$n_reversed > 0) print(x$reversed_rows, row.names = FALSE, digits = digits)
  }
  if (x$k_rev_reached) {
    cat(sprintf("Participants removed to reverse the direction (%s search): %d of %d (%s%%): %s\n", x$method, x$k_rev, x$n,
                format(round(100 * x$share_of_n)), paste(x$subjects, collapse = ", ")))
  } else {
    cat(sprintf("Participants removed to reverse the direction (%s search): not reversed within %d removals of %d\n", x$method, x$max_k, x$n))
  }
  invisible(x)
}
