# Column schema shared by every row the package produces.
ROW_COLS <- c("family", "label", "kind", "role", "is_base", "converged", "note",
              "estimate", "stderr", "df", "lcl", "ucl", "p",
              "n_subj", "n_obs", "aicc", "param", "covariance", "method", "vcov", "covariates", "alpha")

empty_row <- function(spec, label, family, kind, is_base, note, covariates, covariance, method, vcov, role = "sensitivity") {
  structure(data.frame(family = family, label = label, kind = kind, role = role, is_base = is_base, converged = FALSE, note = note,
                       estimate = NA_real_, stderr = NA_real_, df = NA_real_, lcl = NA_real_, ucl = NA_real_, p = NA_real_,
                       n_subj = NA_integer_, n_obs = NA_integer_, aicc = NA_real_, param = NA_real_,
                       covariance = covariance, method = method, vcov = vcov,
                       covariates = paste(covariates, collapse = " + "), alpha = spec$alpha, stringsAsFactors = FALSE),
            class = c("stress_rows", "data.frame"))
}

#' Fit one MMRM and return one row
#'
#' Fits the model described by a [stress_spec()] (optionally on alternative
#' data or with alternative settings) and returns the treatment contrast at the
#' contrast visit as a single row in the package's common schema. This is the
#' engine every family function calls.
#'
#' @param spec A `stress_spec`.
#' @param data Alternative data set in the same layout as `spec$data`; `NULL`
#'   fits the spec's own data.
#' @param label,family,kind Labels for the output row. `kind` is one of
#'   `"alternative"` (a counted alternative analysis), `"deletion"` (a
#'   leave-one-out refit) or `"search"` (a point on a tipping-point grid).
#' @param is_base `TRUE` when the row reproduces the pre-specified analysis
#'   exactly; such rows are not counted in a census.
#' @param role `"sensitivity"` for an analysis that keeps the estimand and
#'   changes an assumption or a modelling choice; `"supplementary"` for one
#'   that targets a different estimand (ICH E9(R1)).
#' @param note Free text carried into the row.
#' @param covariates,covariance,method,vcov Overrides of the spec's settings.
#' @param at Named list of continuous covariates fixed at a value instead of
#'   their mean when forming the least-squares means (SAS `LSMEANS ... AT`).
#' @param weights LS-mean weighting, `"equal"` or `"observed"`; see [stress_spec()].
#'
#' @return A one-row data frame of class `stress_rows` with columns `family`,
#'   `label`, `kind`, `role`, `is_base`, `converged`, `note`, `estimate`, `stderr`,
#'   `df`, `lcl`, `ucl`, `p`, `n_subj`, `n_obs`, `aicc`, `param` (the numeric value of a
#'   continuous perturbation, `NA` otherwise), `covariance`, `method`, `vcov`,
#'   `covariates`, `alpha`.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' stress_fit(spec)
#' @export
stress_fit <- function(spec, data = NULL, label = spec$label, family = "base", kind = "alternative",
                       is_base = is.null(data), note = "", covariates = spec$covariates,
                       covariance = spec$covariance, method = spec$method, vcov = spec$vcov, at = list(), role = "sensitivity",
                       weights = spec$weights) {
  check_spec(spec)
  role <- match.arg(role, c("sensitivity", "supplementary"))
  row <- empty_row(spec, label, family, kind, is_base, note, covariates, covariance, method, vcov, role)
  d <- if (is.null(data)) spec$data else conform_data(spec, data)
  cov_vars <- if (length(covariates)) all.vars(stats::reformulate(covariates)) else character()
  keep <- !is.na(d[[spec$response]])
  if (length(cov_vars)) keep <- keep & stats::complete.cases(d[, cov_vars, drop = FALSE])
  d <- d[keep, , drop = FALSE]
  if (!nrow(d)) { row$note <- paste(note, "[no observations]"); return(row) }
  d[[spec$subject]] <- droplevels(d[[spec$subject]]); d[[spec$visit]] <- droplevels(d[[spec$visit]])
  if (!spec$contrast_visit %in% levels(d[[spec$visit]])) { row$note <- paste(note, "[contrast visit absent]"); return(row) }
  # A class covariate with a single level in this subset is dropped (PROC MIXED zeroes it; R refuses a one-level factor).
  for (v in cov_vars) if (is.factor(d[[v]])) {
    d[[v]] <- droplevels(d[[v]])
    if (nlevels(d[[v]]) < 2L) {
      drop <- vapply(covariates, function(tm) v %in% all.vars(stats::reformulate(tm)), TRUE)
      covariates <- covariates[!drop]; note <- paste(note, sprintf("[%s single-level, term dropped]", v))
    }
  }
  if (!all(c(spec$active, spec$reference) %in% unique(as.character(d[[spec$treatment]])))) { row$note <- trimws(paste(note, "[active or reference arm absent]")); return(row) }
  f <- build_formula(spec, covariates, covariance)
  fit <- tryCatch(mmrm::mmrm(f, data = d, reml = TRUE, control = mmrm::mmrm_control(method = method, vcov = vcov)),
                  error = function(e) e)
  if (inherits(fit, "error")) { row$note <- trimws(paste(note, "[did not converge:", substr(conditionMessage(fit), 1, 60), "]")); return(row) }
  L <- lsmean_L(stats::delete.response(stats::terms(fit$formula_parts$model_formula)), d, spec, names(stats::coef(fit, complete = FALSE)), fit$contrasts, at, weights)
  z <- tryCatch(mmrm::df_1d(fit, L), error = function(e) e)
  if (inherits(z, "error")) { row$note <- trimws(paste(note, "[contrast failed:", substr(conditionMessage(z), 1, 60), "]")); return(row) }
  if (method == "Between-Within" && isTRUE(spec$sas_conventions)) {
    # PROC MIXED between-within df for a within-subject contrast: N - subjects - rank of the within-subject columns of X.
    X <- fit$tmb_data$x_matrix; subj <- d[[spec$subject]]
    within <- vapply(seq_len(ncol(X)), function(j) any(tapply(X[, j], subj, function(v) length(unique(v)) > 1L)), TRUE)
    df_bw <- nrow(X) - nlevels(subj) - sum(within)
    if (abs(z$df - df_bw) > 0.5) {
      note <- paste(note, sprintf("[mmrm BW df %.1f replaced by SAS %.1f]", z$df, df_bw))
      z$df <- df_bw; z$p_val <- 2 * stats::pt(-abs(z$est / z$se), z$df)
    }
  }
  q <- stats::qt(1 - spec$alpha / 2, z$df)
  row$converged <- TRUE; row$note <- trimws(note)
  row$estimate <- z$est; row$stderr <- z$se; row$df <- z$df
  row$lcl <- z$est - q * z$se; row$ucl <- z$est + q * z$se; row$p <- z$p_val
  row$n_subj <- nlevels(d[[spec$subject]]); row$n_obs <- nrow(d)
  # SAS AICC for REML: -2 res.loglik + 2 d n* / (n* - d - 1), d = covariance parameters, n* = N - rank(X)
  dpar <- length(fit$theta_est); nstar <- nrow(d) - length(stats::coef(fit, complete = FALSE))
  row$aicc <- -2 * as.numeric(stats::logLik(fit)) + 2 * dpar * nstar / (nstar - dpar - 1)
  row$covariates <- paste(covariates, collapse = " + ")
  row
}

# L vector for the LS-mean difference (active - reference) at the contrast visit with SAS LSMEANS conventions:
# class covariates averaged with equal weights over their observed levels, continuous covariates at their data means.
# tt: a terms object without response; coefnames: the non-aliased coefficient names of the fitted model.
lsmean_L <- function(tt, d, spec, coefnames, contrasts.arg = NULL, at = list(), weights = spec$weights) {
  vars <- all.vars(tt); trt <- spec$treatment; vis <- spec$visit
  if (identical(weights, "observed")) {   # average the design over the analysis rows, treatment set to each level, visit to the contrast visit
    lv <- c(spec$reference, spec$active); X <- lapply(lv, function(a) { g <- d; g[[trt]] <- factor(a, levels = lv); if (vis %in% vars) g[[vis]] <- factor(spec$contrast_visit, levels = levels(d[[vis]]))
      for (v in names(at)) g[[v]] <- at[[v]]; colMeans(stats::model.matrix(tt, g, contrasts.arg = contrasts.arg)[, coefnames, drop = FALSE]) })
    return(X[[2]] - X[[1]])
  }
  cl <- vars[vapply(vars, function(v) is.factor(d[[v]]), TRUE)]; cl <- setdiff(cl, c(trt, vis))
  co <- setdiff(vars, c(cl, trt, vis))
  grid_list <- lapply(stats::setNames(cl, cl), function(v) levels(droplevels(d[[v]])))
  grid_list[[trt]] <- levels(d[[trt]]); if (vis %in% vars) grid_list[[vis]] <- spec$contrast_visit
  grid <- expand.grid(grid_list, stringsAsFactors = FALSE)
  for (v in cl) grid[[v]] <- factor(grid[[v]], levels = levels(d[[v]]))
  grid[[trt]] <- factor(grid[[trt]], levels = levels(d[[trt]])); if (vis %in% vars) grid[[vis]] <- factor(grid[[vis]], levels = levels(d[[vis]]))
  for (v in co) grid[[v]] <- if (v %in% names(at)) at[[v]] else mean(d[[v]], na.rm = TRUE)
  X <- stats::model.matrix(tt, grid, contrasts.arg = contrasts.arg)
  X <- X[, coefnames, drop = FALSE]   # aliased coefficients are excluded
  colMeans(X[grid[[trt]] == spec$active, , drop = FALSE]) - colMeans(X[grid[[trt]] == spec$reference, , drop = FALSE])
}

# Bind rows from several family calls into one stress_rows data frame.
bind_rows_ <- function(x) {
  x <- x[!vapply(x, is.null, TRUE)]
  if (!length(x)) return(NULL)
  out <- do.call(rbind, lapply(x, function(r) as.data.frame(r)[, ROW_COLS, drop = FALSE]))
  rownames(out) <- NULL
  structure(out, class = c("stress_rows", "data.frame"))
}

# Map a fitting function over items, optionally on a PSOCK cluster (the installed package is loaded on the workers).
stress_map <- function(items, fun, cores = 1L) {
  if (cores <= 1L || length(items) < 2L) return(lapply(items, fun))
  cl <- parallel::makeCluster(min(cores, length(items))); on.exit(parallel::stopCluster(cl), add = TRUE)
  parallel::clusterEvalQ(cl, { requireNamespace("mmrmstress", quietly = TRUE); NULL })
  parallel::parLapplyLB(cl, items, fun)
}

check_spec <- function(spec) if (!inherits(spec, "stress_spec")) stop("spec must be a stress_spec; see stress_spec()")

# Force every argument of the calling function so that closures shipped to parallel workers carry values, not promises.
force_args <- function(env = parent.frame()) { for (n in ls(env, all.names = TRUE)) get(n, envir = env); invisible(NULL) }
