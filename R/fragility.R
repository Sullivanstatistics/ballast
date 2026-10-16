#' Smallest set of subjects whose removal changes the conclusion
#'
#' A greedy forward search: at each step every remaining subject is removed
#' in turn from the current data, the pre-specified model is refitted, and
#' the subject whose removal moves the result furthest towards the target is
#' dropped for good. The search stops when the target is reached or after
#' `max_k` steps. The number of steps needed is a continuous-outcome analogue
#' of the fragility index; because the search is greedy it is an upper bound
#' on the true minimum.
#'
#' @inheritParams stress_covariance
#' @param target What has to change: `"significance"` (the p-value crosses
#'   alpha in either direction, depending on the base result), `"ci"` (the
#'   estimate leaves the base confidence interval) or `"direction"` (the
#'   estimate changes sign).
#' @param max_k Maximum number of subjects to remove.
#' @param candidates Optional character vector of subject identifiers to
#'   restrict the search to (one arm, say).
#' @return A `stress_rows` data frame with one row per step
#'   (`kind = "search"`, so the rows are not counted in a census, since the
#'   search crosses the target by construction; `param` = number removed,
#'   `label` = the subjects removed so far). `attr(, "fragility")` is a list with `target`, `k` (the
#'   step at which the target was reached, `NA` if never), `subjects` and
#'   `reached`.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' fr <- stress_fragility(spec, max_k = 2)
#' attr(fr, "fragility")
#' @export
stress_fragility <- function(spec, target = c("significance", "ci", "direction"), max_k = 5, candidates = NULL, cores = 1L) {
  check_spec(spec); force_args()
  target <- match.arg(target)
  base <- stress_fit(spec); if (!base$converged) stop("the base model did not converge")
  d <- spec$data; sub <- spec$subject; alpha <- spec$alpha
  base_sig <- base$p < alpha; sgn <- sign(base$estimate)
  reached <- function(r) {
    if (!isTRUE(r$converged)) return(FALSE)
    switch(target, significance = (r$p < alpha) != base_sig, ci = r$estimate < base$lcl || r$estimate > base$ucl, direction = sign(r$estimate) != sgn)
  }
  score <- function(r) {     # larger is further towards the target
    if (!isTRUE(r$converged)) return(-Inf)
    switch(target, significance = if (base_sig) r$p else -r$p, ci = -sgn * r$estimate, direction = -sgn * r$estimate)
  }
  pool <- if (is.null(candidates)) levels(d[[sub]]) else as.character(candidates)
  if (!all(pool %in% levels(d[[sub]]))) stop("candidates must be subject identifiers")
  removed <- character(); rows <- list(); hit <- NA_integer_
  for (k in seq_len(max_k)) {
    rem <- setdiff(pool, removed); if (!length(rem)) break
    fits <- stress_map(rem, function(u) stress_fit(spec, data = d[!d[[sub]] %in% c(removed, u), , drop = FALSE]), cores)
    sc <- vapply(fits, score, 0); best <- which.max(sc)
    if (!is.finite(sc[best])) break
    removed <- c(removed, rem[best]); r <- fits[[best]]
    r$family <- "greedy deletion search"; r$label <- paste(removed, collapse = ", "); r$kind <- "search"; r$is_base <- FALSE
    r$param <- k; r$note <- sprintf("step %d removed %s", k, rem[best]); rows[[k]] <- r
    if (reached(r)) { hit <- k; break }
  }
  out <- bind_rows_(rows)
  attr(out, "fragility") <- list(target = target, k = hit, subjects = removed, reached = !is.na(hit),
                                 base_p = base$p, base_estimate = base$estimate)
  out
}
