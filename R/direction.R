#' Direction stability of a result that misses significance
#'
#' A small trial can carry a real effect and still miss significance for want
#' of power, as rare-disease trials often do. For such a result the useful
#' questions are not "did it pass?" but how stable what was seen is: whether
#' any pre-specified re-analysis reverses the direction of the estimate,
#' whether any moves it outside its margin of error, and how many participants
#' must be removed before the direction reverses, against the number a
#' well-behaved trial of the same size and z would need ([deletion_benchmark()]).
#'
#' The report describes the strength and stability of the evidence. It cannot
#' say whether the effect is real: at the same z a chance finding and a real
#' effect behave identically under every re-analysis that keeps the estimand
#' (the methods paper's result T7), so reversal under re-analysis is a function
#' of how far the estimate sits from zero in standard errors, whatever the
#' truth. In the paper's simulations no pre-specified change reversed any
#' result with p between 0.05 and 0.10, real effect or chance alike, and the
#' median number of participants removed to reverse one was 8 against a
#' benchmark of 10. The report is therefore always read beside the p-value,
#' and its print method says so.
#'
#' @param spec A [stress_spec()].
#' @param census Optional `stress_census` over the pre-specified re-analyses.
#'   If given, its counted rows supply the reversal and margin-of-error
#'   counts; without it only the deletion count is computed.
#' @param max_k Most participants to remove in the ranked deletion search
#'   ([stress_fragility()] with `target = "direction"`, `method = "ranked"`).
#'   The default is the reversal benchmark plus five, and at least ten.
#' @param cores Passed to [stress_fragility()].
#' @return A list of class `stress_direction`: `base` (the pre-specified fit),
#'   `z`, `n`, `significant`, `alpha`; from the census `n_counted`,
#'   `n_reversed`, `n_outside_ci` and `reversed_rows` (`NA` and `NULL` without
#'   one); from the search `k_rev` (participants removed to reverse, `NA` if
#'   not reached within `max_k`), `k_rev_reached`, `subjects`, `share_of_n`,
#'   the `benchmark_rev` of [deletion_benchmark()] and their ratio
#'   `removal_ratio_rev`; and `search`, the rows of the search.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' cen <- stress_census(spec, stress_covariance(spec, c("cs", "ar1h")), stress_covariates(spec))
#' stress_direction(spec, cen, max_k = 6)
#' @seealso [stress_verdict()] for the margin-of-error verdict,
#'   [stress_fragility()] and [deletion_benchmark()] for the deletion count and
#'   its benchmark.
#' @export
stress_direction <- function(spec, census = NULL, max_k = NULL, cores = 1L) {
  check_spec(spec); force_args()
  base <- stress_fit(spec); if (!isTRUE(base$converged)) stop("the base model did not converge")
  z <- base$estimate / base$stderr; n <- base$n_subj
  bench <- deletion_benchmark(n, z = z, level = 1 - spec$alpha)
  bench_rev <- unname(bench[["reversal"]])
  if (is.null(max_k)) max_k <- max(10L, if (is.na(bench_rev)) 10L else bench_rev + 5L)
  search <- stress_fragility(spec, target = "direction", max_k = max_k, method = "ranked", cores = cores)
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
                 k_rev = a$k, k_rev_reached = a$reached, max_k = max_k, subjects = a$subjects,
                 share_of_n = if (a$reached) a$k / n else NA_real_,
                 benchmark_rev = bench_rev, removal_ratio_rev = if (a$reached && !is.na(bench_rev)) a$k / bench_rev else NA_real_,
                 search = search), class = "stress_direction")
}

#' @export
print.stress_direction <- function(x, digits = 3, ...) {
  b <- x$base
  cat("Direction stability\n")
  cat(sprintf("Base: estimate %s, %s%% CI %s to %s, p = %s (z = %s); %s at alpha %s\n", format(b$estimate, digits = digits),
              format(100 * (1 - x$alpha)), format(b$lcl, digits = digits), format(b$ucl, digits = digits), format(b$p, digits = digits),
              format(x$z, digits = digits), if (x$significant) "significant" else "not significant", format(x$alpha)))
  if (!is.na(x$n_counted)) {
    cat(sprintf("Pre-specified re-analyses: %d of %d reverse the direction; %d move the estimate outside its margin of error\n",
                x$n_reversed, x$n_counted, x$n_outside_ci))
    if (x$n_reversed > 0) print(x$reversed_rows, row.names = FALSE, digits = digits)
  }
  bench <- if (is.na(x$benchmark_rev)) "no benchmark" else sprintf("%d for a well-behaved trial of this size and z", x$benchmark_rev)
  if (x$k_rev_reached) {
    cat(sprintf("Participants removed to reverse the direction: %d of %d (%s%%), against %s%s\n", x$k_rev, x$n,
                format(round(100 * x$share_of_n)), bench,
                if (is.na(x$removal_ratio_rev)) "" else sprintf(" (ratio %s)", format(x$removal_ratio_rev, digits = 2))))
  } else {
    cat(sprintf("Participants removed to reverse the direction: not reversed within %d removals of %d, against %s\n", x$max_k, x$n, bench))
  }
  stable <- (is.na(x$n_reversed) || x$n_reversed == 0) && (is.na(x$n_outside_ci) || x$n_outside_ci == 0)
  cat(if (stable) "Reads: the direction and size of the estimate do not depend on the analytic choices"
      else "Reads: some pre-specified re-analyses change the direction or leave the margin of error, so the estimate depends on analytic choices",
      if (x$k_rev_reached && !is.na(x$removal_ratio_rev) && x$removal_ratio_rev >= 0.5) ", and the result does not rest on a few participants.\n"
      else if (x$k_rev_reached) ", and the result rests on fewer participants than a well-behaved trial would.\n" else ".\n", sep = "")
  cat("This describes the strength and stability of the evidence. At the same z a chance finding behaves the same way under every\n",
      "re-analysis that keeps the estimand, so it does not show that the effect is real; read it beside the p-value.\n", sep = "")
  invisible(x)
}
