#' Perturbation family: within-subject covariance structure
#'
#' Refits the pre-specified model under each covariance structure. The row that
#' reproduces the spec's own structure is flagged `is_base`.
#'
#' @param spec A [stress_spec()].
#' @param structures Covariance structure names (see [stress_spec()]).
#' @param cores Number of worker processes; `1` fits sequentially.
#' @return A `stress_rows` data frame, one row per structure.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' stress_covariance(spec, c("us", "cs", "ar1h"))
#' @export
stress_covariance <- function(spec, structures = c("us", "ar1h", "ar1", "cs", "csh", "toep", "toeph"), cores = 1L) {
  check_spec(spec); force_args()
  structures <- match.arg(structures, COV_STRUCTURES, several.ok = TRUE)
  bind_rows_(stress_map(structures, function(s)
    stress_fit(spec, label = s, family = "covariance structure", is_base = identical(s, spec$covariance), covariance = s), cores))
}

#' Default inference settings for [stress_inference()]
#'
#' @return A named list of `list(method = , vcov = )` pairs: Satterthwaite,
#'   Kenward-Roger, linear Kenward-Roger (the SAS `DDFM=KR` default), residual,
#'   sandwich with between-within degrees of freedom (SAS `EMPIRICAL`) and the
#'   jackknife sandwich.
#' @examples
#' names(default_inference())
#' @export
default_inference <- function() list(
  "Satterthwaite" = list(method = "Satterthwaite", vcov = "Asymptotic"),
  "Kenward-Roger" = list(method = "Kenward-Roger", vcov = "Kenward-Roger"),
  "Kenward-Roger (linear)" = list(method = "Kenward-Roger", vcov = "Kenward-Roger-Linear"),
  "Residual" = list(method = "Residual", vcov = "Asymptotic"),
  "Sandwich, between-within" = list(method = "Between-Within", vcov = "Empirical"),
  "Jackknife sandwich, between-within" = list(method = "Between-Within", vcov = "Empirical-Jackknife"))

#' Perturbation family: degrees-of-freedom method and variance estimator
#'
#' @inheritParams stress_covariance
#' @param settings Named list of `list(method = , vcov = )` pairs; see
#'   [default_inference()].
#' @return A `stress_rows` data frame, one row per setting.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' stress_inference(spec, default_inference()[c("Satterthwaite", "Kenward-Roger (linear)")])
#' @export
stress_inference <- function(spec, settings = default_inference(), cores = 1L) {
  check_spec(spec); force_args()
  if (is.null(names(settings)) || any(names(settings) == "")) stop("settings must be a named list")
  bind_rows_(stress_map(names(settings), function(nm) {
    s <- settings[[nm]]
    stress_fit(spec, label = nm, family = "inference", is_base = identical(s$method, spec$method) && identical(s$vcov, spec$vcov),
               method = s$method, vcov = s$vcov)
  }, cores))
}

#' Perturbation family: covariate set
#'
#' Refits the model with each covariate dropped in turn, with no covariates,
#' and with any user-supplied covariate sets.
#'
#' @inheritParams stress_covariance
#' @param drop_each Drop each pre-specified covariate term in turn.
#' @param drop_all Fit with treatment and visit only.
#' @param sets Named list of additional covariate sets (formulas or character
#'   vectors of term labels); each is fitted as given.
#' @return A `stress_rows` data frame.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' stress_covariates(spec, sets = list("with weight" = ~ RACE + SEX + FEV1_BL + WEIGHT))
#' @export
stress_covariates <- function(spec, drop_each = TRUE, drop_all = TRUE, sets = list(), cores = 1L) {
  check_spec(spec); force_args()
  all_sets <- list()
  if (drop_each) for (v in spec$covariates) all_sets[[paste("without", v)]] <- setdiff(spec$covariates, v)
  if (drop_all && length(spec$covariates) > 1L) all_sets[["no covariates"]] <- character()
  if (length(sets)) { if (is.null(names(sets)) || any(names(sets) == "")) stop("sets must be named"); all_sets <- c(all_sets, lapply(sets, parse_covariates)) }
  if (!length(all_sets)) return(NULL)
  bind_rows_(stress_map(names(all_sets), function(nm)
    stress_fit(spec, label = nm, family = "covariate set", is_base = setequal(all_sets[[nm]], spec$covariates), covariates = all_sets[[nm]]), cores))
}

#' Perturbation family: alternative analysis data sets
#'
#' The generic data-decision family. Each alternative is a data frame in the
#' spec's layout (an intercurrent-event handling, a different baseline
#' definition, a contested record reversed, a different visit window). The
#' pre-specified model is refitted on each.
#'
#' @inheritParams stress_covariance
#' @param alternatives Named list of data frames.
#' @param family Family label for the rows.
#' @param role `"supplementary"` (the default: an alternative data set usually
#'   targets a different estimand) or `"sensitivity"`.
#' @return A `stress_rows` data frame, one row per alternative.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' alt <- mmrm::fev_data
#' alt$FEV1[alt$USUBJID == "PT1"] <- NA   # one subject's records set missing
#' stress_data(spec, list("PT1 removed" = alt))
#' @export
stress_data <- function(spec, alternatives, family = "data handling", role = "supplementary", cores = 1L) {
  check_spec(spec); force_args()
  if (is.null(names(alternatives)) || any(names(alternatives) == "")) stop("alternatives must be a named list of data frames")
  bind_rows_(stress_map(names(alternatives), function(nm)
    stress_fit(spec, data = alternatives[[nm]], label = nm, family = family, is_base = FALSE, role = role), cores))
}

#' Perturbation family: analysis population
#'
#' Each rule is a function of the spec's data returning a logical vector of
#' rows to keep (a per-protocol flag, a completer definition, a cohort).
#'
#' @inheritParams stress_covariance
#' @param rules Named list of functions `function(data) logical`.
#' @param role `"supplementary"` (the default: a different population is a
#'   different estimand) or `"sensitivity"`.
#' @return A `stress_rows` data frame, one row per rule.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' stress_population(spec, list("female" = function(d) d$SEX == "Female"))
#' @export
stress_population <- function(spec, rules, role = "supplementary", cores = 1L) {
  check_spec(spec); force_args()
  if (is.null(names(rules)) || any(names(rules) == "")) stop("rules must be a named list of functions")
  alts <- lapply(rules, function(f) { k <- f(spec$data); spec$data[!is.na(k) & k, , drop = FALSE] })
  stress_data(spec, alts, family = "analysis population", role = role, cores = cores)
}

#' Perturbation family: leave-one-out deletions
#'
#' Refits the model with each subject removed, or with each level of a
#' grouping variable (site, cohort, country) removed. Rows are `kind =
#' "deletion"` and are summarised separately from alternative analyses.
#'
#' @inheritParams stress_covariance
#' @param by Name of a grouping column; `NULL` deletes subjects one at a time.
#' @return A `stress_rows` data frame, one row per deleted unit.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:40), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL)
#' stress_loo(spec, by = "RACE")
#' @export
stress_loo <- function(spec, by = NULL, cores = 1L) {
  check_spec(spec); force_args()
  d <- spec$data
  if (is.null(by)) { key <- as.character(d[[spec$subject]]); units <- levels(d[[spec$subject]]); fam <- "leave-one-out: subject" }
  else { if (!by %in% names(d)) stop("column not in data: ", by); key <- as.character(d[[by]]); units <- sort(unique(key[!is.na(key)])); fam <- paste0("leave-one-out: ", by) }
  bind_rows_(stress_map(units, function(u) {
    keep <- is.na(key) | key != u
    n_rm <- length(unique(d[[spec$subject]][!keep]))
    stress_fit(spec, data = d[keep, , drop = FALSE], label = u, family = fam, kind = "deletion", is_base = FALSE,
               note = sprintf("%d subject%s removed", n_rm, if (n_rm == 1L) "" else "s"))
  }, cores))
}

#' Perturbation family: crossed specification grid
#'
#' Fits every combination of the supplied covariance structures, inference
#' settings, covariate sets and data sets (a specification curve). The cell
#' that reproduces the spec is flagged `is_base`.
#'
#' @inheritParams stress_covariance
#' @param covariance Character vector of covariance structures.
#' @param inference Named list of `list(method = , vcov = )` pairs.
#' @param covariates Named list of covariate sets (formulas or term labels).
#' @param data Named list of data frames; a `NULL` element is the spec's data.
#' @return A `stress_rows` data frame, one row per cell, labelled
#'   `"covariance | inference | covariates | data"`.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' stress_grid(spec, covariance = c("us", "cs"),
#'             covariates = list(full = ~ RACE + SEX + FEV1_BL, baseline = ~ FEV1_BL))
#' @export
stress_grid <- function(spec, covariance = spec$covariance,
                        inference = list(base = list(method = spec$method, vcov = spec$vcov)),
                        covariates = list(base = spec$covariates), data = list(base = NULL), cores = 1L) {
  check_spec(spec); force_args()
  covariance <- match.arg(covariance, COV_STRUCTURES, several.ok = TRUE)
  name_it <- function(x, what) { if (is.null(names(x))) names(x) <- paste0(what, seq_along(x)); x }
  inference <- name_it(inference, "inf"); covariates <- lapply(name_it(covariates, "cov"), parse_covariates); data <- name_it(data, "data")
  cells <- expand.grid(cv = covariance, inf = names(inference), cs = names(covariates), dt = names(data), stringsAsFactors = FALSE)
  items <- split(cells, seq_len(nrow(cells)))
  bind_rows_(stress_map(items, function(ce) {
    inf <- inference[[ce$inf]]; cs <- covariates[[ce$cs]]; dt <- data[[ce$dt]]
    is_base <- identical(ce$cv, spec$covariance) && identical(inf$method, spec$method) && identical(inf$vcov, spec$vcov) &&
      setequal(cs, spec$covariates) && is.null(dt)
    stress_fit(spec, data = dt, label = paste(ce$cv, ce$inf, ce$cs, ce$dt, sep = " | "), family = "specification grid",
               is_base = is_base, covariates = cs, covariance = ce$cv, method = inf$method, vcov = inf$vcov)
  }, cores))
}

#' Perturbation family: re-randomisation (permutation) test
#'
#' Permutes treatment labels across subjects, optionally within strata, refits
#' the pre-specified model each time and returns the permutation p-value for
#' the observed contrast. The returned row carries the observed estimate and
#' the permutation p; the null distribution is attached as `attr(, "null")`.
#'
#' @inheritParams stress_covariance
#' @param n Number of permutations.
#' @param strata Name of a subject-level column to permute within; `NULL`
#'   permutes freely.
#' @param statistic `"estimate"` (the contrast; the permutation refits skip
#'   the adjusted degrees of freedom, so this is the fast choice) or `"t"`
#'   (estimate over its standard error, refitted with the spec's inference).
#' @param seed Random seed.
#' @return A one-row `stress_rows` data frame with `p` equal to
#'   `(1 + number of |null| >= |observed|) / (n + 1)`.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL)
#' stress_permute(spec, n = 19)
#' @export
stress_permute <- function(spec, n = 1000, strata = NULL, statistic = c("estimate", "t"), seed = 1, cores = 1L) {
  check_spec(spec); force_args()
  statistic <- match.arg(statistic)
  base <- stress_fit(spec)
  if (!base$converged) stop("the base model did not converge")
  d <- spec$data; sub <- spec$subject; trt <- spec$treatment
  s <- d[!duplicated(d[[sub]]), c(sub, trt, strata), drop = FALSE]
  if (!is.null(strata)) {
    if (!strata %in% names(d)) stop("column not in data: ", strata)
    if (any(tapply(as.character(d[[strata]]), d[[sub]], function(x) length(unique(x))) > 1L)) stop("strata must be constant within subject")
  }
  set.seed(seed)
  arm <- s[[trt]]; str <- if (is.null(strata)) rep(1L, nrow(s)) else as.character(s[[strata]])
  perms <- lapply(seq_len(n), function(i) { a <- arm; for (g in unique(str)) { k <- which(str == g); a[k] <- arm[k][sample.int(length(k))] }; a })
  idx <- match(d[[sub]], s[[sub]])
  stat <- function(r) if (!r$converged) NA_real_ else if (statistic == "t") r$estimate / r$stderr else r$estimate
  # the contrast estimate does not depend on the df method, so the estimate statistic skips the adjusted df and vcov
  fast <- if (statistic == "estimate") list(method = "Residual", vcov = "Asymptotic") else list(method = spec$method, vcov = spec$vcov)
  null <- unlist(stress_map(perms, function(a) { dp <- d; dp[[trt]] <- a[idx]; stat(stress_fit(spec, data = dp, method = fast$method, vcov = fast$vcov)) }, cores))
  obs <- stat(base); ok <- !is.na(null)
  p <- (1 + sum(abs(null[ok]) >= abs(obs))) / (sum(ok) + 1)
  row <- base
  row$family <- "re-randomisation test"; row$label <- sprintf("%d permutations%s", n, if (is.null(strata)) "" else paste0(" within ", strata))
  row$is_base <- FALSE; row$kind <- "alternative"; row$p <- p; row$df <- NA_real_; row$lcl <- NA_real_; row$ucl <- NA_real_; row$aicc <- NA_real_
  row$note <- sprintf("statistic = %s; %d of %d permutations converged; seed %s", statistic, sum(ok), n, format(seed))
  attr(row, "null") <- null
  row
}

#' Perturbation family: least-squares-mean weighting
#'
#' Refits the pre-specified model and forms the treatment contrast with the
#' other weighting of the class covariates: equal weights over levels (SAS
#' `LSMEANS` default) versus the observed covariate distribution of the
#' analysis rows (SAS `OBSMARGINS`, g-computation). The point estimate differs
#' only when a class covariate interacts with treatment or visit; the two
#' rows otherwise coincide.
#'
#' @inheritParams stress_covariance
#' @return A `stress_rows` data frame with two rows, one flagged `is_base`.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' stress_weights(spec)
#' @export
stress_weights <- function(spec, cores = 1L) {
  check_spec(spec); force_args()
  bind_rows_(stress_map(c("equal", "observed"), function(w)
    stress_fit(spec, label = paste(w, "LS-mean weights"), family = "LS-mean weighting", is_base = identical(w, spec$weights), weights = w), cores))
}
