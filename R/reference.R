#' Perturbation family: reference-based multiple imputation
#'
#' Imputes the missing responses from a multivariate-normal imputation model
#' (an MMRM on the observed data with treatment by visit, the subject-level
#' covariates and an unstructured covariance) under the standard
#' reference-based assumptions (Carpenter, Roger and Kenward, 2013), refits
#' the pre-specified model on each completed data set and pools with Rubin's
#' rules:
#'
#' * `MAR`: every subject's missing values follow their own arm.
#' * `J2R` (jump to reference): an active-arm subject's visits after the last
#'   observed one take the reference arm's means.
#' * `CR` (copy reference): an active-arm subject with any missing value
#'   follows the reference arm's means at every visit.
#' * `CIR` (copy increments in reference): after the last observed visit the
#'   subject keeps their own-arm mean at that visit and then changes as the
#'   reference arm does.
#'
#' Visits missing before the last observed one are treated as missing at
#' random under every assumption. Parameter uncertainty is carried by
#' approximate Bayesian draws: for each imputation the imputation model is
#' refitted on a bootstrap sample of subjects (stratified by arm) and its
#' fixed effects and covariance are used to draw the missing values from the
#' conditional normal distribution given the subject's observed values.
#' An optional `delta` is added to every imputed value of the active arm.
#'
#' @inheritParams stress_tipping
#' @param methods Assumptions to run, from `"MAR"`, `"J2R"`, `"CR"`, `"CIR"`.
#' @param delta Shift added to the active arm's imputed values (response
#'   units); `0` for none.
#' @param same_cov If `TRUE` one covariance matrix is shared by both arms in
#'   the imputation model; if `FALSE` each arm has its own, and the reference
#'   arm's is used for the reference-based draws.
#' @param max_tries Bootstrap refits attempted per imputation before giving up.
#' @details Imputation `i` uses seed `seed + i` on whichever worker draws it, so
#'   the result is the same for any number of `cores`.
#' @return A `stress_rows` data frame, one counted row per method
#'   (`role = "sensitivity"`), with the number of imputations and the Monte
#'   Carlo standard error in `note`.
#' @references Carpenter JR, Roger JH, Kenward MG (2013). Analysis of
#'   longitudinal trials with protocol deviation: a framework for relevant,
#'   accessible assumptions, and inference via multiple imputation. Journal of
#'   Biopharmaceutical Statistics 23, 1352-1371.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:100), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' \donttest{stress_reference(spec, methods = c("MAR", "J2R"), m = 3)}
#' @export
stress_reference <- function(spec, methods = c("MAR", "J2R", "CR", "CIR"), m = 25, seed = 1, delta = 0, arm = NULL,
                             impute_covariates = NULL, same_cov = TRUE, max_tries = 3L, cores = 1L) {
  check_spec(spec); force_args()
  methods <- match.arg(methods, c("MAR", "J2R", "CR", "CIR"), several.ok = TRUE)
  trt <- spec$treatment; sub <- spec$subject; vis <- spec$visit; y <- spec$response
  if (is.null(arm)) arm <- spec$active
  ref <- spec$reference
  fr <- mi_frame(spec, impute_covariates); w <- fr$w; visits <- fr$visits; ycols <- fr$ycols; nv <- length(visits)
  Y <- as.matrix(w[, ycols]); miss <- is.na(Y)
  if (!any(miss)) stop("no missing responses to impute")
  # imputation model on the long data of the wide frame (subject-level covariates only)
  long0 <- fr$lengthen(w); long0 <- long0[!is.na(long0[[y]]), , drop = FALSE]
  long0[[vis]] <- factor(long0[[vis]], levels = visits); long0[[sub]] <- factor(long0[[sub]])
  rhs <- c(fr$imp_vars, trt, vis, paste0(trt, ":", vis), if (same_cov) paste0("us(", vis, " | ", sub, ")") else paste0("us(", vis, " | ", trt, " / ", sub, ")"))
  f_imp <- stats::as.formula(paste(y, "~", paste(rhs, collapse = " + ")), env = globalenv())
  tt <- stats::delete.response(stats::terms(stats::reformulate(c(fr$imp_vars, trt, vis, paste0(trt, ":", vis)))))
  fit_imp <- function(dd) tryCatch(mmrm::mmrm(f_imp, data = dd, reml = TRUE, control = mmrm::mmrm_control(method = "Satterthwaite")), error = function(e) NULL)
  # design rows for every subject at every visit under its own arm and under the reference arm
  grid_for <- function(arm_value) { g <- w[rep(seq_len(nrow(w)), each = nv), c(sub, trt, fr$imp_vars), drop = FALSE]; g[[vis]] <- factor(rep(visits, nrow(w)), levels = visits)
    g[[trt]] <- factor(arm_value, levels = spec$treatment_levels); g }
  g_own <- grid_for(as.character(w[[trt]])[rep(seq_len(nrow(w)), each = nv)]); g_ref <- grid_for(ref)
  last_obs <- apply(!miss, 1, function(o) if (any(o)) max(which(o)) else 0L)
  is_active <- w[[trt]] == arm
  subj_arm <- as.character(w[[trt]])
  draw_params <- function() {
    for (try in seq_len(max_tries)) {
      idx <- unlist(lapply(split(seq_len(nrow(w)), subj_arm), function(k) sample(k, length(k), replace = TRUE)))
      wb <- w[idx, , drop = FALSE]; wb[[sub]] <- paste0("b", seq_len(nrow(wb)))
      lb <- fr$lengthen(wb); lb <- lb[!is.na(lb[[y]]), , drop = FALSE]; lb[[vis]] <- factor(lb[[vis]], levels = visits); lb[[sub]] <- factor(lb[[sub]])
      fb <- fit_imp(lb)
      if (!is.null(fb)) return(fb)
    }
    NULL
  }
  sigma_of <- function(fit, arm_value) { S <- mmrm::VarCorr(fit); if (is.list(S) && !is.matrix(S)) S <- S[[arm_value]]; S[visits, visits, drop = FALSE] }
  means_of <- function(fit, grid) { X <- stats::model.matrix(tt, grid); b <- stats::coef(fit, complete = FALSE); matrix(as.vector(X[, match_coef(names(b), colnames(X)), drop = FALSE] %*% b), ncol = nv, byrow = TRUE) }
  draws <- stress_map(seq_len(m), function(i) {
    set.seed(seed + i)   # one seed per imputation, set on the worker, so results do not depend on the number of cores
    fb <- draw_params(); if (is.null(fb)) return(NULL)
    mu_own <- means_of(fb, g_own); mu_ref <- means_of(fb, g_ref)
    S_own <- lapply(stats::setNames(spec$treatment_levels, spec$treatment_levels), function(a) sigma_of(fb, a))
    lapply(stats::setNames(methods, methods), function(meth) {
      Yi <- Y
      for (s in which(rowSums(miss) > 0)) {
        mu <- mu_own[s, ]; S <- S_own[[subj_arm[s]]]; lo <- last_obs[s]; post <- seq_len(nv) > lo
        if (is_active[s] && meth != "MAR") {
          if (meth == "CR") mu <- mu_ref[s, ]
          if (meth == "J2R") mu[post] <- mu_ref[s, post]
          if (meth == "CIR" && lo > 0) mu[post] <- mu_own[s, lo] + (mu_ref[s, post] - mu_ref[s, lo])
          if (meth == "CIR" && lo == 0) mu <- mu_ref[s, ]
          S <- S_own[[ref]]
        }
        u <- which(miss[s, ]); o <- which(!miss[s, ])
        if (length(o)) { Soo <- S[o, o, drop = FALSE]; Suo <- S[u, o, drop = FALSE]; A <- Suo %*% solve(Soo)
          cm <- mu[u] + as.vector(A %*% (Y[s, o] - mu[o])); cv <- S[u, u, drop = FALSE] - A %*% t(Suo) }
        else { cm <- mu[u]; cv <- S[u, u, drop = FALSE] }
        cv <- (cv + t(cv)) / 2; R <- tryCatch(chol(cv), error = function(e) chol(cv + diag(1e-8, nrow(cv))))
        val <- cm + as.vector(t(R) %*% stats::rnorm(length(u)))
        if (is_active[s] && delta != 0) val <- val + delta
        Yi[s, u] <- val
      }
      wi <- w; wi[, ycols] <- Yi; wi
    })
  }, cores)
  draws <- draws[!vapply(draws, is.null, TRUE)]
  if (!length(draws)) stop("no bootstrap refit of the imputation model converged")
  note <- sprintf("reference %s, shift %s on %s, %s covariance, seed %s", ref, format(delta), arm, if (same_cov) "common" else "arm-specific", format(seed))
  bind_rows_(lapply(methods, function(meth) {
    fits <- lapply(draws, function(dr) stress_fit(spec, data = fr$lengthen(dr[[meth]])))
    mi_row(spec, fits, if (delta == 0) meth else sprintf("%s, delta %s", meth, format(delta)), "reference-based multiple imputation",
           "alternative", "sensitivity", note, m, nrow(w), param = if (delta == 0) NA_real_ else delta)
  }))
}
