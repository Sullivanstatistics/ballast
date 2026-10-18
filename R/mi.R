# Multiple imputation by fully conditional specification (regression method) with an MNAR shift,
# following the algorithms of SAS PROC MI (FCS REG, MNAR ADJUST) and PROC MIANALYZE (Rubin's rules).
#
# Regression draw for one imputed variable Y on covariates X with n observed rows and p columns:
#   sigma*^2 = sigma_hat^2 (n - p) / g,  g ~ chi-square(n - p)
#   beta*    = beta_hat + sigma* V_h' z,  V = (X'X)^-1 = V_h' V_h, z ~ N(0, I)
#   y_imp    = x' beta* + sigma* e,       e ~ N(0, 1)
# FCS: a preliminary fill (each imputed variable regressed on the preceding variables), then nbiter burn-in
# iterations in which each imputed variable is regressed on all other variables at their current values. The
# shift is added to the imputed values of the selected variables on the selected rows at every draw, which is
# what reproduces the SAS tipping-point curve (checked 7 Oct 2026 against the SAS reference run).

mi_reg_impute <- function(y, X, Xmis) {
  qrX <- qr(X); keep <- qrX$pivot[seq_len(qrX$rank)]            # drop aliased columns, as PROC MI does
  X <- X[, keep, drop = FALSE]; Xmis <- Xmis[, keep, drop = FALSE]
  n <- nrow(X); p <- ncol(X); nu <- n - p
  if (nu < 1L) stop("imputation model has more parameters than observed rows")
  XtXi <- chol2inv(chol(crossprod(X)))
  bhat <- XtXi %*% crossprod(X, y); rss <- sum((y - X %*% bhat)^2)
  s2 <- rss / stats::rchisq(1, nu)                               # sigma_hat^2 nu / g
  Vh <- chol(XtXi)
  bstar <- bhat + sqrt(s2) * t(Vh) %*% stats::rnorm(p)
  as.vector(Xmis %*% bstar + sqrt(s2) * stats::rnorm(nrow(Xmis)))
}

mi_design <- function(df, vars) if (length(vars)) stats::model.matrix(stats::reformulate(vars), df) else matrix(1, nrow(df), 1)

# w: wide data frame; vars: imputation variables in order (covariates first); adjust: NULL or list(vars, shift, rows).
mi_fcs_reg <- function(w, vars, nimp, seed, nbiter = 10, adjust = NULL, shift_every = TRUE) {
  set.seed(seed)
  imputed <- vars[vapply(vars, function(v) anyNA(w[[v]]), TRUE)]
  misl <- lapply(stats::setNames(imputed, imputed), function(v) is.na(w[[v]]))
  shift <- function(cur, tg) {
    if (!is.null(adjust) && tg %in% adjust$vars && adjust$shift != 0) { k <- misl[[tg]] & adjust$rows; cur[[tg]][k] <- cur[[tg]][k] + adjust$shift }
    cur
  }
  lapply(seq_len(nimp), function(i) {
    cur <- w
    for (tg in imputed) {                                           # preliminary fill on the preceding variables
      mis <- misl[[tg]]; cov <- vars[seq_len(match(tg, vars) - 1L)]
      fit <- !mis & stats::complete.cases(cur[, cov, drop = FALSE])
      cur[[tg]][mis] <- mi_reg_impute(cur[[tg]][fit], mi_design(cur[fit, , drop = FALSE], cov), mi_design(cur[mis, , drop = FALSE], cov))
      if (shift_every) cur <- shift(cur, tg)
    }
    for (it in seq_len(nbiter)) for (tg in imputed) {               # burn-in on all other variables
      mis <- misl[[tg]]; cov <- setdiff(vars, tg)
      cur[[tg]][mis] <- mi_reg_impute(cur[[tg]][!mis], mi_design(cur[!mis, , drop = FALSE], cov), mi_design(cur[mis, , drop = FALSE], cov))
      if (shift_every) cur <- shift(cur, tg)
    }
    if (!shift_every) for (tg in imputed) cur <- shift(cur, tg)
    cur
  })
}

# Rubin's rules as PROC MIANALYZE (no EDF adjustment).
mi_pool <- function(est, se, alpha = 0.05) {
  ok <- !is.na(est) & !is.na(se); est <- est[ok]; se <- se[ok]; m <- length(est)
  if (!m) return(NULL)
  qbar <- mean(est); ubar <- mean(se^2); b <- if (m > 1L) stats::var(est) else 0
  tv <- ubar + (1 + 1 / m) * b
  df <- if (b > 0) (m - 1) * (1 + ubar / ((1 + 1 / m) * b))^2 else Inf
  t <- qbar / sqrt(tv); q <- stats::qt(1 - alpha / 2, df)
  list(estimate = qbar, stderr = sqrt(tv), df = df, lcl = qbar - q * sqrt(tv), ucl = qbar + q * sqrt(tv),
       p = 2 * stats::pt(-abs(t), df), m = m, mcse = sqrt(b / m))
}

# One row per subject with the subject-level covariates and one response column per visit (.y_1, .y_2, ...), plus a
# function that turns a completed wide frame back into the spec's long layout (visit-level covariates re-attached).
mi_frame <- function(spec, impute_covariates = NULL) {
  d <- spec$data; sub <- spec$subject; vis <- spec$visit; trt <- spec$treatment; y <- spec$response
  subj_level <- vapply(spec$cov_vars, function(v) all(tapply(d[[v]], d[[sub]], function(x) length(unique(x)) == 1L)), TRUE)
  sl_vars <- spec$cov_vars[subj_level]; vl_vars <- spec$cov_vars[!subj_level]
  imp_vars <- if (is.null(impute_covariates)) sl_vars else as.character(impute_covariates)
  if (!all(imp_vars %in% names(d))) stop("impute_covariates not in data: ", paste(setdiff(imp_vars, names(d)), collapse = ", "))
  if (!all(imp_vars %in% sl_vars)) stop("impute_covariates must be constant within subject: ", paste(setdiff(imp_vars, sl_vars), collapse = ", "))
  w <- d[!duplicated(d[[sub]]), c(sub, trt, sl_vars), drop = FALSE]; rownames(w) <- NULL
  w <- w[stats::complete.cases(w[, c(trt, sl_vars), drop = FALSE]), , drop = FALSE]
  visits <- spec$visit_levels; ycols <- paste0(".y_", seq_along(visits))
  key_d <- paste(d[[sub]], as.character(d[[vis]]))
  for (j in seq_along(visits)) w[[ycols[j]]] <- d[[y]][match(paste(w[[sub]], visits[j]), key_d)]
  lengthen <- function(wi) {
    long <- do.call(rbind, lapply(seq_along(visits), function(j) { x <- wi[, c(sub, trt, sl_vars), drop = FALSE]; x[[vis]] <- visits[j]; x[[y]] <- wi[[ycols[j]]]; x }))
    if (length(vl_vars)) { key <- paste(long[[sub]], long[[vis]]); for (v in vl_vars) long[[v]] <- d[[v]][match(key, key_d)] }
    long
  }
  list(w = w, sl_vars = sl_vars, vl_vars = vl_vars, imp_vars = imp_vars, visits = visits, ycols = ycols, lengthen = lengthen)
}

# Pool a list of per-imputation stress_fit rows into one row.
mi_row <- function(spec, fits, label, family, kind, role, note_prefix, m, n_subj, param = NA_real_) {
  est <- vapply(fits, function(r) r$estimate, 0); se <- vapply(fits, function(r) r$stderr, 0)
  pl <- mi_pool(est, se, spec$alpha)
  row <- empty_row(spec, label, family, kind, FALSE, "", spec$covariates, spec$covariance, spec$method, spec$vcov, role)
  if (is.null(pl)) { row$note <- "no imputation fit converged"; return(row) }
  row$converged <- TRUE; row$estimate <- pl$estimate; row$stderr <- pl$stderr; row$df <- pl$df
  row$lcl <- pl$lcl; row$ucl <- pl$ucl; row$p <- pl$p; row$param <- param
  row$n_subj <- n_subj; row$n_obs <- as.integer(round(mean(vapply(fits, function(r) as.numeric(r$n_obs), 0))))
  row$note <- sprintf("%s; m = %d of %d converged; MC SE of estimate %.3g", note_prefix, pl$m, m, pl$mcse)
  row
}

#' Perturbation family: delta-adjusted multiple imputation (tipping point)
#'
#' Imputes the missing responses by fully conditional specification
#' (regression method, one column per visit, subject-level covariates and
#' treatment as predictors), adds `delta` to every imputed value of the active
#' arm, refits the pre-specified model on each completed data set and pools
#' with Rubin's rules. `delta = 0` is the missing-at-random multiple-imputation
#' analysis and is a counted alternative; other deltas are tipping-point
#' searches (`kind = "search"`). Rows carry the delta in `param`.
#'
#' Covariates that vary within subject are excluded from the imputation model
#' and are kept in the analysis model; subject-visit rows absent from the data
#' are created for the imputed response with those covariates missing, so they
#' drop out of the refit.
#'
#' @inheritParams stress_covariance
#' @param deltas Shifts added to the imputed values of the active arm, in
#'   response units.
#' @param m Number of imputations.
#' @param seed Random seed (the same seed is used for every delta).
#' @param arm Treatment level receiving the shift; defaults to the active arm.
#' @param shift_visits Visit levels whose imputed values are shifted; `NULL`
#'   shifts every visit.
#' @param impute_covariates Subject-level covariates used as predictors in the
#'   imputation model (with treatment and the visit columns); `NULL` uses every
#'   spec covariate that is constant within subject. Covariates that vary
#'   within subject cannot be used.
#' @param nbiter Burn-in iterations of the FCS sampler.
#' @param shift_every If `TRUE` the shift is applied at every draw (SAS `MNAR
#'   ADJUST` under FCS); if `FALSE` only to the final imputation.
#' @return A `stress_rows` data frame, one row per delta; `note` records the
#'   number of imputations and the Monte Carlo standard error of the pooled
#'   estimate.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:80), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL)
#' stress_tipping(spec, deltas = c(0, -5), m = 3)
#' @export
stress_tipping <- function(spec, deltas = seq(0, -10, by = -2), m = 25, seed = 1, arm = NULL, shift_visits = NULL,
                           impute_covariates = NULL, nbiter = 10, shift_every = TRUE, cores = 1L) {
  check_spec(spec); force_args()
  if (is.null(arm)) arm <- spec$active
  if (!arm %in% spec$treatment_levels) stop("arm must be a treatment level")
  fr <- mi_frame(spec, impute_covariates); w <- fr$w; visits <- fr$visits; ycols <- fr$ycols
  if (is.null(shift_visits)) shift_visits <- visits
  if (!all(shift_visits %in% visits)) stop("shift_visits must be visit levels")
  shift_cols <- ycols[match(shift_visits, visits)]
  vars <- c(spec$treatment, fr$imp_vars, ycols); rows_arm <- w[[spec$treatment]] == arm
  note <- sprintf("shift on %s at %s; seed %s", arm, if (identical(shift_visits, visits)) "all visits" else paste(shift_visits, collapse = ", "), format(seed))
  one_delta <- function(delta) {
    imps <- mi_fcs_reg(w, vars, m, seed, nbiter, adjust = list(vars = shift_cols, shift = delta, rows = rows_arm), shift_every)
    fits <- lapply(imps, function(wi) stress_fit(spec, data = fr$lengthen(wi)))
    mi_row(spec, fits, sprintf("delta %s", format(delta)), "delta-adjusted multiple imputation",
           if (delta == 0) "alternative" else "search", "sensitivity", note, m, nrow(w), param = delta)
  }
  bind_rows_(stress_map(deltas, one_delta, cores))
}
