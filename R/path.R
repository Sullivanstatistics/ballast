#' Candidate analytic changes for the path search
#'
#' Lists the analytic changes [stress_path()] may combine. Each change belongs
#' to a family (covariance structure, inference, covariate set, LS-mean
#' weighting, reference-based imputation, analysis data set), and a path
#' changes each family at most once. Participant and site deletions are not
#' analytic changes; they are measured separately by [stress_fragility()].
#'
#' @param spec A [stress_spec()].
#' @param covariance Alternative covariance structures.
#' @param inference Named list of `list(method = , vcov = )` alternatives.
#' @param covariates `TRUE` to drop each covariate and (with two or more) all
#'   of them; a named list of covariate sets to use instead; `FALSE` for none.
#' @param weights `TRUE` to include the other LS-mean weighting.
#' @param reference Reference-based imputation assumptions (any of `"MAR"`,
#'   `"J2R"`, `"CR"`, `"CIR"`); `character()` for none.
#' @param delta_adjusted Shifts for delta-adjusted imputation under MAR. Each
#'   value is one change that adds the shift to every imputed value of the
#'   active arm (for example minus half the residual SD, against the active
#'   arm). It belongs to the reference-based imputation family, so a path uses
#'   at most one missing-data assumption. `numeric()` for none.
#' @param m Imputations per reference-based analysis.
#' @param data Named list of alternative analysis data sets (for example,
#'   other intercurrent-event handlings).
#' @return A list of changes, each a list with `family`, `label`, `type`
#'   (`"spec"` or `"mi"`) and `value`.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + FEV1_BL)
#' vapply(path_changes(spec, reference = character()), `[[`, "", "label")
#' @export
path_changes <- function(spec, covariance = c("us", "ar1h", "cs"),
                         inference = default_inference()[c("Satterthwaite", "Kenward-Roger (linear)", "Sandwich, between-within")],
                         covariates = TRUE, weights = TRUE, reference = c("J2R", "CR", "CIR"), delta_adjusted = numeric(),
                         m = 10, data = list()) {
  check_spec(spec)
  out <- list()
  add <- function(family, label, type, value) out[[length(out) + 1L]] <<- list(family = family, label = label, type = type, value = value)
  if (length(covariance)) covariance <- match.arg(covariance, COV_STRUCTURES, several.ok = TRUE)
  for (s in setdiff(covariance, spec$covariance)) add("covariance structure", s, "spec", list(covariance = s))
  for (nm in names(inference)) {
    x <- inference[[nm]]
    if (!(identical(x$method, spec$method) && identical(x$vcov, spec$vcov))) add("inference", nm, "spec", list(method = x$method, vcov = x$vcov))
  }
  if (isTRUE(covariates)) {
    for (v in spec$covariates) add("covariate set", paste("without", v), "spec", list(covariates = setdiff(spec$covariates, v)))
    if (length(spec$covariates) > 1L) add("covariate set", "no covariates", "spec", list(covariates = character()))
  } else if (is.list(covariates)) {
    if (is.null(names(covariates)) || any(names(covariates) == "")) stop("covariate sets must be named")
    for (nm in names(covariates)) add("covariate set", nm, "spec", list(covariates = parse_covariates(covariates[[nm]])))
  }
  if (isTRUE(weights)) { w <- setdiff(c("equal", "observed"), spec$weights); add("LS-mean weighting", paste(w, "LS-mean weights"), "spec", list(weights = w)) }
  if (length(reference)) reference <- match.arg(reference, c("MAR", "J2R", "CR", "CIR"), several.ok = TRUE)
  for (r in reference) add("reference-based multiple imputation", r, "mi", list(method = r, m = m, delta = 0))
  for (d in delta_adjusted) add("reference-based multiple imputation", sprintf("MAR, delta %s", format(d)), "mi", list(method = "MAR", m = m, delta = d))
  if (length(data) && (is.null(names(data)) || any(names(data) == ""))) stop("data sets must be named")
  for (nm in names(data)) add("analysis data set", nm, "spec", list(data = data[[nm]]))
  out
}

#' Smallest combination of analytic changes that leaves the confidence interval
#'
#' A greedy search for the fewest analytic changes, made together, that move
#' the estimate outside the pre-specified 95% confidence interval. At each step every change from
#' a family not yet used is tried on top of the changes already made, and the
#' one that moves the estimate furthest in the search direction is kept. The
#' search stops when the estimate leaves the interval or `max_j` changes have
#' been made. It runs towards zero (the direction that weakens the result) and,
#' with `direction = "both"`, also away from zero; `j` is the smaller count.
#'
#' Changes combine: a reference-based or delta-adjusted imputation chosen at
#' one step is kept, and later changes are evaluated under it. A path that
#' leaves the interval through either is flagged `assumption_dependent`, so that
#' the reader can see the path ran through a missing-data assumption rather
#' than through the observed data alone.
#'
#' Because the search is greedy, `j` is an upper bound on the smallest
#' combination; to first order the shifts of different families add, so the
#' greedy path is the worst case when they do.
#'
#' The search is exact but avoids repeated work: the imputation draws are
#' made once per imputation model and reused by every change that leaves the
#' model alone, a state reached twice (by both directions, or by two orders of
#' the same changes) is fitted once, and the second direction is searched
#' only as far as it could still give a shorter path than the first.
#'
#' @param spec A [stress_spec()]: the pre-specified analysis.
#' @param changes Candidate changes from [path_changes()].
#' @param max_j Largest number of changes to combine.
#' @param direction `"both"`, `"toward_zero"` or `"away_from_zero"`.
#' @param seed Seed for the reference-based imputations.
#' @param cores Worker processes (or a cluster) for the candidates of a step.
#' @return A `stress_rows` data frame with one row per step of each direction
#'   searched (`family` is `"analytic path"`), with attribute `"path"`: a list
#'   with `j` (`NA` if not reached within `max_j`), `reached`, `direction`,
#'   `changes` (the labels of the path that reached the boundary first),
#'   `assumption_dependent` and the base estimate and interval.
#' @examples
#' \donttest{
#' d <- simulate_rare_trial(25, delta = 6, population = "mixture", seed = 2)
#' spec <- stress_spec(d, "y", "id", "visit", "arm", "REF", covariates = ~ base + fast,
#'                     method = "Satterthwaite", vcov = "Asymptotic")
#' p <- stress_path(spec, path_changes(spec, reference = "J2R", m = 5), max_j = 3)
#' attr(p, "path")$j
#' }
#' @seealso [stress_fragility()] for the deletion searches.
#' @export
stress_path <- function(spec, changes = path_changes(spec), max_j = 3, direction = c("both", "toward_zero", "away_from_zero"),
                        seed = 1, cores = 1L) {
  check_spec(spec); force_args(); direction <- match.arg(direction)
  if (!length(changes)) stop("no changes to search over")
  base <- stress_fit(spec); if (!isTRUE(base$converged)) stop("the base model did not converge")
  sgn <- sign(base$estimate)
  mi_changes <- Filter(function(ch) ch$type == "mi", changes)
  mi_methods <- unique(vapply(mi_changes, function(ch) ch$value$method, ""))
  mi_m <- if (length(mi_changes)) max(vapply(mi_changes, function(ch) ch$value$m, 0)) else 0
  # Two caches. The imputation draws depend only on the analysis data and the covariates, so every change that leaves
  # those alone (covariance, weighting, the method or the delta) reuses them. The fitted result of a state (spec plus
  # imputation) is kept so that a state reached again, by the other direction or by another order of the same changes,
  # is not refitted; in particular the first step is evaluated once for both directions.
  draws_cache <- new.env(parent = emptyenv()); fit_cache <- new.env(parent = emptyenv())
  draws_for <- function(sp) {
    key <- imputation_key(sp)
    if (!exists(key, envir = draws_cache, inherits = FALSE))
      assign(key, tryCatch(reference_draws(sp, mi_methods, mi_m, seed), error = function(e) NULL), envir = draws_cache)
    get(key, envir = draws_cache, inherits = FALSE)
  }
  apply_change <- function(state, ch) {
    if (ch$type == "spec") state$spec <- do.call(spec_update, c(list(state$spec), ch$value)) else state$mi <- ch$value
    state
  }
  state_key <- function(state) paste(spec_key(state$spec), if (is.null(state$mi)) "" else paste(state$mi$method, state$mi$delta))
  evaluate <- function(state) {
    r <- tryCatch({
      if (is.null(state$mi)) stress_fit(state$spec)
      else { dr <- draws_for(state$spec); if (is.null(dr)) stop("imputation failed")
             reference_analyse(state$spec, dr, state$mi$method, if (is.null(state$mi$delta)) 0 else state$mi$delta) }
    }, error = function(e) NULL)
    if (is.null(r)) NULL else r[1, , drop = FALSE]
  }
  evaluate_all <- function(states) {
    keys <- vapply(states, state_key, "")
    todo <- which(!vapply(keys, function(k) exists(k, envir = fit_cache, inherits = FALSE), TRUE))
    if (length(todo)) {
      for (i in todo) if (!is.null(states[[i]]$mi)) draws_for(states[[i]]$spec)   # drawn here, so the cache is shared
      new <- stress_map(states[todo], evaluate, cores)
      for (k in seq_along(todo)) assign(keys[todo[k]], new[[k]], envir = fit_cache)
    }
    lapply(keys, function(k) get(k, envir = fit_cache, inherits = FALSE))
  }
  search <- function(dir, limit) {                # dir = -1 moves towards zero, +1 away from zero
    state <- list(spec = spec, mi = NULL); used <- character(); labels <- character(); rows <- list(); hit <- NA_integer_
    for (j in seq_len(limit)) {
      cand <- Filter(function(ch) !ch$family %in% used, changes)
      if (!length(cand)) break
      fits <- evaluate_all(lapply(cand, function(ch) apply_change(state, ch)))
      est <- vapply(fits, function(r) if (!is.null(r) && isTRUE(r$converged)) r$estimate else NA_real_, 0)
      if (all(is.na(est))) break
      best <- which.max(dir * sgn * est)
      state <- apply_change(state, cand[[best]]); used <- c(used, cand[[best]]$family); labels <- c(labels, cand[[best]]$label)
      r <- fits[[best]]
      r$family <- "analytic path"; r$kind <- "search"; r$is_base <- FALSE; r$param <- j
      r$label <- paste(labels, collapse = " + "); r$note <- sprintf("%s, step %d", if (dir < 0) "toward zero" else "away from zero", j)
      rows[[j]] <- r
      if (r$estimate < base$lcl || r$estimate > base$ucl) { hit <- j; break }
    }
    list(rows = rows, j = hit, labels = labels, mi = !is.null(state$mi))
  }
  dirs <- switch(direction, both = c(-1, 1), toward_zero = -1, away_from_zero = 1)
  # The second direction can only win with a shorter path, so it is searched no further than that.
  res <- list(); limit <- max_j
  for (dv in dirs) {
    res[[length(res) + 1L]] <- if (limit >= 1) search(dv, limit) else list(rows = list(), j = NA_integer_, labels = character(), mi = FALSE)
    if (!is.na(res[[length(res)]]$j)) limit <- min(limit, res[[length(res)]]$j - 1L)
  }
  js <- vapply(res, function(x) x$j, 0L)
  win <- if (all(is.na(js))) 1L else which.min(replace(js, is.na(js), Inf))
  all_rows <- unlist(lapply(res, `[[`, "rows"), recursive = FALSE)
  out <- if (length(all_rows)) bind_rows_(all_rows) else data.frame()
  attr(out, "path") <- list(j = res[[win]]$j, reached = !is.na(res[[win]]$j), direction = if (dirs[win] < 0) "toward zero" else "away from zero",
                            changes = res[[win]]$labels, assumption_dependent = !is.na(res[[win]]$j) && res[[win]]$mi,
                            base_estimate = base$estimate, base_lcl = base$lcl, base_ucl = base$ucl, max_j = max_j)
  out
}

# Keys for the caches of stress_path(). The analysis data are identified by their size and a few sums of the response.
data_key <- function(sp) {
  y <- sp$data[[sp$response]]; y <- y[!is.na(y)]
  paste(nrow(sp$data), length(unique(sp$data[[sp$subject]])), format(sum(y), digits = 17), format(sum(y^2), digits = 17),
        format(sum(seq_along(y) * y), digits = 17))
}
imputation_key <- function(sp) paste(data_key(sp), paste(sp$cov_vars, collapse = ","), sp$active)
spec_key <- function(sp) paste(imputation_key(sp), sp$covariance, sp$weights, sp$method, sp$vcov, paste(sp$covariates, collapse = "+"), sp$contrast_visit, sp$alpha)
