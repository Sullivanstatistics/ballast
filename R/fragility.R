#' Smallest set of subjects whose removal changes the conclusion
#'
#' Two searches for the fewest subjects whose removal moves the result to the
#' target. The number needed is a continuous-outcome analogue of the
#' fragility index; both searches give an upper bound on the true minimum.
#'
#' * `method = "greedy"` (default): at each step every remaining subject is
#'   removed in turn from the current data, the pre-specified model is
#'   refitted, and the subject whose removal moves the result furthest
#'   towards the target is dropped for good. About `k * n` refits.
#' * `method = "ranked"`: subjects are ranked once, by how far removing each
#'   alone moves the result towards the target (the leave-one-out refits),
#'   and the top 1, 2, ..., k are removed together, one refit per step. About
#'   `n + k` refits, so it is practical for large trials. It is the quantity
#'   that [deletion_benchmark()] approximates: removing the k largest
#'   influences at once.
#'
#' @inheritParams stress_covariance
#' @param target What has to change: `"significance"` (the p-value crosses
#'   alpha in either direction, depending on the base result), `"ci"` (the
#'   estimate leaves the base confidence interval) or `"direction"` (the
#'   estimate changes sign).
#' @param max_k Maximum number of subjects to remove.
#' @param candidates Optional character vector of subject identifiers to
#'   restrict the search to (one arm, say).
#' @param method `"greedy"` or `"ranked"`.
#' @return A `stress_rows` data frame with one row per step
#'   (`kind = "search"`, so the rows are not counted in a census, since the
#'   search crosses the target by construction; `param` = number removed,
#'   `label` = the subjects removed so far). `attr(, "fragility")` is a list with `target`, `method`, `k` (the
#'   step at which the target was reached, `NA` if never), `subjects` and
#'   `reached`.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' fr <- stress_fragility(spec, max_k = 2)
#' attr(fr, "fragility")
#' attr(stress_fragility(spec, "ci", max_k = 10, method = "ranked"), "fragility")$k
#' @export
stress_fragility <- function(spec, target = c("significance", "ci", "direction"), max_k = 5, candidates = NULL, cores = 1L,
                             method = c("greedy", "ranked")) {
  check_spec(spec); force_args()
  target <- match.arg(target); method <- match.arg(method)
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
  step_row <- function(r, k, family, note) {
    r$family <- family; r$label <- paste(removed, collapse = ", "); r$kind <- "search"; r$is_base <- FALSE
    r$param <- k; r$note <- note; r
  }
  if (method == "greedy") {
    for (k in seq_len(max_k)) {
      rem <- setdiff(pool, removed); if (!length(rem)) break
      fits <- stress_map(rem, function(u) stress_fit(spec, data = d[!d[[sub]] %in% c(removed, u), , drop = FALSE]), cores)
      sc <- vapply(fits, score, 0); best <- which.max(sc)
      if (!is.finite(sc[best])) break
      removed <- c(removed, rem[best])
      rows[[k]] <- step_row(fits[[best]], k, "greedy deletion search", sprintf("step %d removed %s", k, rem[best]))
      if (reached(rows[[k]])) { hit <- k; break }
    }
  } else {
    single <- stress_map(pool, function(u) stress_fit(spec, data = d[d[[sub]] != u, , drop = FALSE]), cores)
    order_ids <- pool[order(vapply(single, score, 0), decreasing = TRUE)]
    for (k in seq_len(min(max_k, length(order_ids)))) {
      removed <- order_ids[seq_len(k)]
      r <- stress_fit(spec, data = d[!d[[sub]] %in% removed, , drop = FALSE])
      rows[[k]] <- step_row(r, k, "ranked deletion search", sprintf("step %d removed %s", k, order_ids[k]))
      if (reached(rows[[k]])) { hit <- k; break }
    }
  }
  out <- bind_rows_(rows)
  attr(out, "fragility") <- list(target = target, method = method, k = hit, subjects = removed, reached = !is.na(hit),
                                 base_p = base$p, base_estimate = base$estimate)
  out
}
