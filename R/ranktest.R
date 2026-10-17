#' Perturbation family: rank tests at the contrast visit
#'
#' Model-free tests of the treatment difference in the response at the
#' contrast visit: the Wilcoxon rank-sum test (normal approximation with the
#' tie correction and continuity correction, as SAS `PROC NPAR1WAY` reports
#' it) and, if `strata` is given, the van Elteren test (the Cochran-Mantel-
#' Haenszel row-mean-score statistic on modified ridit scores within strata).
#' The rows carry a p-value and the Hodges-Lehmann shift as the estimate, with
#' no standard error or interval; they count towards significance only.
#'
#' @inheritParams stress_covariance
#' @param strata Name of a subject-level stratification column for the van
#'   Elteren test; `NULL` runs the Wilcoxon test only.
#' @return A `stress_rows` data frame with one or two rows.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' stress_ranktest(spec, strata = "RACE")
#' @export
stress_ranktest <- function(spec, strata = NULL, cores = 1L) {
  check_spec(spec); force_args()
  d <- spec$data; d <- d[as.character(d[[spec$visit]]) == spec$contrast_visit & !is.na(d[[spec$response]]), , drop = FALSE]
  y <- d[[spec$response]]; g <- as.character(d[[spec$treatment]])
  keep <- g %in% c(spec$reference, spec$active); y <- y[keep]; g <- g[keep]; d <- d[keep, , drop = FALSE]
  act <- g == spec$active
  mk <- function(label, p, est, note) {
    row <- empty_row(spec, label, "rank test", "alternative", FALSE, note, character(), spec$covariance, "Normal", "none")
    row$converged <- TRUE; row$p <- p; row$estimate <- est; row$n_subj <- length(y); row$n_obs <- length(y); row
  }
  # Wilcoxon rank sum, normal approximation with tie correction and continuity correction (NPAR1WAY)
  r <- rank(y); n1 <- sum(act); n2 <- sum(!act); n <- n1 + n2
  S <- sum(r[act]); ES <- n1 * (n + 1) / 2
  ties <- table(r); VS <- n1 * n2 / 12 * ((n + 1) - sum(ties^3 - ties) / (n * (n - 1)))
  z <- (S - ES - sign(S - ES) * 0.5) / sqrt(VS); p_w <- 2 * stats::pnorm(-abs(z))
  hl <- stats::median(outer(y[act], y[!act], "-"))
  rows <- list(mk("Wilcoxon rank sum", p_w, hl, sprintf("normal approximation with tie and continuity correction; estimate = Hodges-Lehmann shift; n = %d vs %d", n1, n2)))
  if (!is.null(strata)) {
    if (!strata %in% names(d)) stop("column not in data: ", strata)
    s <- as.character(d[[strata]]); num <- 0; den <- 0; ys <- signif(y, 12)   # PROC FREQ forms levels from formatted values, so near-equal doubles tie
    for (k in unique(s)) {
      i <- s == k; nk <- sum(i); n1k <- sum(act[i]); if (nk < 2L || n1k == 0L || n1k == nk) next
      a <- rank(ys[i]) / (nk + 1)                                     # modified ridit scores (SAS MODRIDIT: rank / (n_k + 1)), which carry the van Elteren weighting
      w <- 1
      Tk <- sum(a[act[i]]); ETk <- n1k * mean(a); VTk <- n1k * (nk - n1k) / (nk * (nk - 1)) * sum((a - mean(a))^2)
      num <- num + w * (Tk - ETk); den <- den + w^2 * VTk
    }
    p_v <- if (den > 0) stats::pchisq(num^2 / den, 1, lower.tail = FALSE) else NA_real_
    rows[[2]] <- mk(paste("van Elteren stratified by", strata), p_v, hl, sprintf("CMH row-mean-score statistic on modified ridit scores, strata = %s", strata))
  }
  bind_rows_(rows)
}
