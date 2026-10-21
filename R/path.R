#' Candidate analytic changes for the path search
#'
#' Lists the analytic changes [stress_path()] may combine. Each change belongs
#' to a family (covariance structure, inference, covariate set, LS-mean
#' weighting, reference-based imputation, analysis data set), and a path
#' changes each family at most once. Participant and site deletions are not
#' analytic changes; they are the data axis of the definition and are measured
#' separately by [stress_fragility()] and [deletion_benchmark()].
#'
#' @param spec A [stress_spec()].
#' @param covariance Alternative covariance structures.
#' @param inference Named list of `list(method = , vcov = )` alternatives.
#' @param covariates `TRUE` to drop each covariate and (with two or more) all
#'   of them; a named list of covariate sets to use instead; `FALSE` for none.
#' @param weights `TRUE` to include the other LS-mean weighting.
#' @param reference Reference-based imputation assumptions (any of `"MAR"`,
#'   `"J2R"`, `"CR"`, `"CIR"`); `character()` for none.
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
                         covariates = TRUE, weights = TRUE, reference = c("J2R", "CR", "CIR"), m = 10, data = list()) {
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
  for (r in reference) add("reference-based multiple imputation", r, "mi", list(method = r, m = m))
  if (length(data) && (is.null(names(data)) || any(names(data) == ""))) stop("data sets must be named")
  for (nm in names(data)) add("analysis data set", nm, "spec", list(data = data[[nm]]))
  out
}

#' Smallest combination of analytic changes that leaves the confidence interval
#'
#' The analytic axis of the margin-of-error definition: a greedy search for
#' the fewest analytic changes, made together, that move the estimate outside
#' the pre-specified 95% confidence interval. At each step every change from
#' a family not yet used is tried on top of the changes already made, and the
#' one that moves the estimate furthest in the search direction is kept. The
#' search stops when the estimate leaves the interval or `max_j` changes have
#' been made. It runs towards zero (the direction that weakens the result) and,
#' with `direction = "both"`, also away from zero; `j` is the smaller count.
#'
#' Changes combine: a reference-based imputation chosen at one step is kept,
#' and later changes are evaluated under it. A path that leaves the interval
#' through a reference-based imputation is flagged `assumption_dependent`:
#' the conclusion then rests on an untestable assumption about dropouts
#' rather than on the observed data.
#'
#' Because the search is greedy, `j` is an upper bound on the smallest
#' combination; to first order the shifts of different families add, so the
#' greedy path is the worst case when they do.
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
#' @seealso [deletion_benchmark()] for the data axis.
#' @export
stress_path <- function(spec, changes = path_changes(spec), max_j = 3, direction = c("both", "toward_zero", "away_from_zero"),
                        seed = 1, cores = 1L) {
  check_spec(spec); force_args(); direction <- match.arg(direction)
  if (!length(changes)) stop("no changes to search over")
  base <- stress_fit(spec); if (!isTRUE(base$converged)) stop("the base model did not converge")
  sgn <- sign(base$estimate)
  apply_change <- function(state, ch) {
    if (ch$type == "spec") state$spec <- do.call(spec_update, c(list(state$spec), ch$value)) else state$mi <- ch$value
    state
  }
  evaluate <- function(state) {
    r <- if (is.null(state$mi)) stress_fit(state$spec) else stress_reference(state$spec, methods = state$mi$method, m = state$mi$m, seed = seed)
    r[1, , drop = FALSE]
  }
  search <- function(dir) {                       # dir = -1 moves towards zero, +1 away from zero
    state <- list(spec = spec, mi = NULL); used <- character(); labels <- character(); rows <- list(); hit <- NA_integer_
    for (j in seq_len(max_j)) {
      cand <- Filter(function(ch) !ch$family %in% used, changes)
      if (!length(cand)) break
      fits <- stress_map(cand, function(ch) tryCatch(evaluate(apply_change(state, ch)), error = function(e) NULL), cores)
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
  res <- lapply(dirs, search)
  js <- vapply(res, function(x) x$j, 0L)
  win <- if (all(is.na(js))) 1L else which.min(replace(js, is.na(js), Inf))
  all_rows <- unlist(lapply(res, `[[`, "rows"), recursive = FALSE)
  out <- if (length(all_rows)) bind_rows_(all_rows) else data.frame()
  attr(out, "path") <- list(j = res[[win]]$j, reached = !is.na(res[[win]]$j), direction = if (dirs[win] < 0) "toward zero" else "away from zero",
                            changes = res[[win]]$labels, assumption_dependent = !is.na(res[[win]]$j) && res[[win]]$mi,
                            base_estimate = base$estimate, base_lcl = base$lcl, base_ucl = base$ucl, max_j = max_j)
  out
}

#' Deletions a well-behaved trial would need to change its conclusion
#'
#' The data axis of the margin-of-error definition compares the number of
#' participants whose removal moves the estimate outside the pre-specified
#' interval (`k_ci`, from `stress_fragility(spec, "ci", method = "ranked")`) with the number a
#' trial of the same size with normally distributed influences would need.
#'
#' Removing participant *i* moves the estimate by about \eqn{-\psi_i / n}, which
#' is \eqn{\psi_i / (\sigma_\psi \sqrt{n})} pre-specified standard errors.
#' Removing the k most influential moves it by about \eqn{S_k / \sqrt{n}}, where
#' for standard-normal influences \eqn{S_k = n \phi(\Phi^{-1}(1 - k/n))} is the
#' expected sum of the k largest. The benchmark for leaving the interval is the
#' smallest k with \eqn{S_k \ge c \sqrt{n}}; it does not depend on the effect.
#' The benchmarks for losing significance (\eqn{(|z| - c)\sqrt{n}}) and for
#' reversing the direction (\eqn{|z|\sqrt{n}}) do, which is why a deletion
#' count aimed at significance largely restates the p-value. The
#' approximation needs k small relative to n and is least reliable below
#' about 30 participants; below about 24 no k reaches the interval benchmark.
#'
#' @param n Number of participants in the analysis.
#' @param z Pre-specified z-statistic (estimate / SE); needed for the
#'   significance and reversal benchmarks.
#' @param level Confidence level of the pre-specified interval.
#' @return `deletion_benchmark()`: a named integer vector with `ci` and, if
#'   `z` is given, `significance` (`NA` when the result is not significant)
#'   and `reversal`. `removal_ratio()`: `k_ci` divided by the `ci` benchmark.
#' @examples
#' deletion_benchmark(105, z = 2.18)
#' removal_ratio(9, 105)
#' sapply(c(30, 50, 100, 200, 500), function(n) deletion_benchmark(n)[["ci"]])
#' @export
deletion_benchmark <- function(n, z = NULL, level = 0.95) {
  if (length(n) != 1L || n < 4) stop("n must be a single number of at least 4")
  crit <- stats::qnorm(1 - (1 - level) / 2); k <- seq_len(n - 1L)
  s_k <- n * stats::dnorm(stats::qnorm(1 - k / n))
  first <- function(target) { hit <- which(s_k >= target); if (length(hit)) as.integer(k[hit[1]]) else NA_integer_ }
  out <- c(ci = first(crit * sqrt(n)))
  if (!is.null(z)) out <- c(out, significance = if (abs(z) > crit) first((abs(z) - crit) * sqrt(n)) else NA_integer_, reversal = first(abs(z) * sqrt(n)))
  out
}

#' @rdname deletion_benchmark
#' @param k_ci Observed deletions to leave the interval (`NA` if not reached).
#' @export
removal_ratio <- function(k_ci, n, level = 0.95) unname(k_ci / deletion_benchmark(n, level = level)[["ci"]])
