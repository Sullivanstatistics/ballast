#' Perturbation family: estimator class
#'
#' Refits the question with estimators other than the pre-specified MMRM:
#'
#' * `"complete_cases"`: the pre-specified MMRM on subjects observed at every
#'   visit (no reliance on missing-at-random within the likelihood).
#' * `"gee_independence"`: working-independence weighted least squares with a
#'   visit-specific residual variance and a cluster-robust (sandwich)
#'   variance, between-within degrees of freedom; no within-subject
#'   covariance is modelled. Needs `nlme`.
#' * `"ancova"`: analysis of covariance at the contrast visit, observed cases,
#'   residual degrees of freedom. Covariate terms involving the visit variable
#'   are dropped.
#' * `"robust_ancova"`: MM-type robust regression at the contrast visit
#'   (`MASS::rlm`), normal-theory inference. Needs `MASS`.
#' * `"clda"`: constrained longitudinal data analysis: the raw outcome
#'   (`baseline` plus the response, which must be a change from baseline) is
#'   modelled at baseline and every post-baseline visit with one common
#'   baseline mean across arms, an unstructured covariance over all visits and
#'   the other covariates as fixed effects; the contrast is the difference in
#'   the arms' means at the contrast visit. Needs `baseline`.
#' * `"random_intercept"`: the pre-specified fixed effects with `random` as a
#'   random intercept instead of a fixed covariate, the spec's covariance
#'   structure within subject where `nlme` has an equivalent (`us`, `ar1h`,
#'   `ar1`, `cs`, `csh`); normal-theory inference. Needs `nlme` and `random`.
#'
#' Every estimator reports the same least-squares-mean contrast at the
#' contrast visit (class covariates at equal weights, continuous covariates at
#' their means).
#'
#' @inheritParams stress_covariance
#' @param estimators Which estimators to run.
#' @param random Name of a grouping column for `"random_intercept"` (a site or
#'   centre variable that is also one of the spec's covariates).
#' @param baseline Name of the baseline column for `"clda"`; the response must
#'   be change from that baseline.
#' @param seed Seed for the robust regression's random initial estimate.
#' @return A `stress_rows` data frame, one row per estimator.
#' @examples
#' spec <- stress_spec(mmrm::fev_data, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO",
#'                     covariates = ~ RACE + SEX + FEV1_BL)
#' stress_estimator(spec, c("complete_cases", "ancova"))
#' @export
stress_estimator <- function(spec, estimators = c("complete_cases", "gee_independence", "ancova", "robust_ancova", "random_intercept", "clda"),
                             random = NULL, baseline = NULL, seed = 1, cores = 1L) {
  check_spec(spec); force_args()
  estimators <- match.arg(estimators, c("complete_cases", "gee_independence", "ancova", "robust_ancova", "random_intercept", "clda"), several.ok = TRUE)
  if ("random_intercept" %in% estimators && is.null(random)) { estimators <- setdiff(estimators, "random_intercept"); message("random_intercept skipped: no `random` variable given") }
  if ("clda" %in% estimators && is.null(baseline)) { estimators <- setdiff(estimators, "clda"); message("clda skipped: no `baseline` variable given") }
  fam <- "estimator class"
  bind_rows_(stress_map(estimators, function(e) switch(e,
    complete_cases = est_complete(spec, fam), gee_independence = est_gee(spec, fam), ancova = est_ancova(spec, fam, robust = FALSE, seed = seed),
    robust_ancova = est_ancova(spec, fam, robust = TRUE, seed = seed), random_intercept = est_random(spec, fam, random), clda = est_clda(spec, fam, baseline)), cores))
}

# a finished row from an estimate, SE and df (NA df = normal theory)
est_row <- function(spec, label, family, est, se, df, n_subj, n_obs, note = "") {
  row <- empty_row(spec, label, family, "alternative", FALSE, note, spec$covariates, spec$covariance, spec$method, spec$vcov)
  row$method <- if (is.na(df)) "Normal" else "Residual"; row$vcov <- "see note"
  if (is.na(est) || is.na(se)) return(row)
  q <- if (is.na(df)) stats::qnorm(1 - spec$alpha / 2) else stats::qt(1 - spec$alpha / 2, df)
  row$converged <- TRUE; row$estimate <- est; row$stderr <- se; row$df <- df
  row$lcl <- est - q * se; row$ucl <- est + q * se
  row$p <- if (is.na(df)) 2 * stats::pnorm(-abs(est / se)) else 2 * stats::pt(-abs(est / se), df)
  row$n_subj <- n_subj; row$n_obs <- n_obs; row
}

# analysis data: non-missing response, complete covariates, dropped levels
est_data <- function(spec, covariates = spec$covariates) {
  d <- spec$data; cov_vars <- if (length(covariates)) all.vars(stats::reformulate(covariates)) else character()
  keep <- !is.na(d[[spec$response]]); if (length(cov_vars)) keep <- keep & stats::complete.cases(d[, cov_vars, drop = FALSE])
  d <- d[keep, , drop = FALSE]; d[[spec$subject]] <- droplevels(d[[spec$subject]]); d[[spec$visit]] <- droplevels(d[[spec$visit]])
  for (v in cov_vars) if (is.factor(d[[v]])) d[[v]] <- droplevels(d[[v]])
  d
}

est_complete <- function(spec, fam) {
  d <- est_data(spec); nv <- length(spec$visit_levels)
  cnt <- tapply(as.character(d[[spec$visit]]), d[[spec$subject]], function(v) length(unique(v)))
  keep <- names(cnt)[cnt == nv]
  r <- stress_fit(spec, data = d[d[[spec$subject]] %in% keep, , drop = FALSE], label = "MMRM on complete cases", family = fam, is_base = FALSE,
                  note = sprintf("%d of %d subjects observed at all %d visits", length(keep), length(cnt), nv))
  r$method <- spec$method; r$vcov <- spec$vcov; r
}

est_gee <- function(spec, fam) {
  if (!requireNamespace("nlme", quietly = TRUE)) return(est_row(spec, "GEE independence, robust variance", fam, NA, NA, NA, NA, NA, "nlme not installed"))
  d <- est_data(spec); resp <- spec$response; sub <- spec$subject; vis <- spec$visit; trt <- spec$treatment
  f <- stats::reformulate(c(spec$covariates, trt, vis, paste0(trt, ":", vis)), response = resp)
  X <- stats::model.matrix(f, d)
  qrX <- qr(X); if (qrX$rank < ncol(X)) X <- X[, qrX$pivot[seq_len(qrX$rank)], drop = FALSE]   # full-rank design for gls
  xn <- paste0(".x", seq_len(ncol(X))); dd <- data.frame(y = d[[resp]], X); names(dd) <- c("y", xn); dd$.visit <- d[[vis]]
  fx <- stats::as.formula(paste("y ~ 0 +", paste(xn, collapse = " + ")))
  g <- tryCatch(nlme::gls(fx, data = dd, weights = nlme::varIdent(form = ~ 1 | .visit), method = "REML"), error = function(e) e)
  if (inherits(g, "error")) return(est_row(spec, "GEE independence, robust variance", fam, NA, NA, NA, NA, NA, paste("gls failed:", substr(conditionMessage(g), 1, 60))))
  w <- 1 / (g$sigma / nlme::varWeights(g$modelStruct$varStruct))^2
  b <- stats::coef(g); names(b) <- colnames(X); r <- d[[resp]] - as.vector(X %*% b)
  bread <- solve(crossprod(X * w, X))
  meat <- Reduce(`+`, lapply(split(seq_len(nrow(X)), d[[sub]]), function(i) { u <- crossprod(X[i, , drop = FALSE] * w[i], r[i]); u %*% t(u) }))
  V <- bread %*% meat %*% bread
  L <- lsmean_L(stats::delete.response(stats::terms(f)), d, spec, colnames(X))
  within <- vapply(seq_len(ncol(X)), function(j) any(tapply(X[, j], d[[sub]], function(v) length(unique(v)) > 1L)), TRUE)
  est_row(spec, "GEE independence, robust variance", fam, sum(L * b), sqrt(as.numeric(t(L) %*% V %*% L)), nrow(X) - nlevels(d[[sub]]) - sum(within),
          nlevels(d[[sub]]), nrow(d), "heteroscedastic WLS, cluster sandwich, between-within df")
}

est_ancova <- function(spec, fam, robust, seed) {
  vis <- spec$visit; trt <- spec$treatment
  covs <- spec$covariates[!vapply(spec$covariates, function(tm) vis %in% all.vars(stats::reformulate(tm)), TRUE)]
  d <- est_data(spec, covs); d <- d[as.character(d[[vis]]) == spec$contrast_visit, , drop = FALSE]
  for (v in all.vars(stats::reformulate(c(covs, "1")))) if (is.factor(d[[v]])) d[[v]] <- droplevels(d[[v]])
  lab <- if (robust) "MM robust regression at the contrast visit" else "ANCOVA at the contrast visit"
  if (!nrow(d) || nlevels(droplevels(d[[trt]])) < 2L) return(est_row(spec, lab, fam, NA, NA, NA, NA, NA, "contrast visit not estimable"))
  covs <- covs[vapply(covs, function(tm) all(vapply(all.vars(stats::reformulate(tm)), function(v) !is.factor(d[[v]]) || nlevels(d[[v]]) > 1L, TRUE)), TRUE)]
  f <- stats::reformulate(c(covs, trt), response = spec$response)
  if (robust) {
    if (!requireNamespace("MASS", quietly = TRUE)) return(est_row(spec, lab, fam, NA, NA, NA, NA, NA, "MASS not installed"))
    old_rng <- rng_state(); on.exit(rng_restore(old_rng), add = TRUE); set.seed(seed); fit <- tryCatch(MASS::rlm(f, data = d, method = "MM"), error = function(e) NULL)
    if (is.null(fit)) return(est_row(spec, lab, fam, NA, NA, NA, NA, NA, "rlm did not converge"))
    b <- stats::coef(fit); V <- stats::vcov(fit); df <- NA_real_
  } else {
    fit <- stats::lm(f, data = d); b <- stats::coef(fit); ok <- !is.na(b); b <- b[ok]; V <- stats::vcov(fit)[ok, ok, drop = FALSE]; df <- fit$df.residual
  }
  L <- lsmean_L(stats::delete.response(stats::terms(f)), d, spec, names(b))
  est_row(spec, lab, fam, sum(L * b), sqrt(as.numeric(t(L) %*% V %*% L)), df, nrow(d), nrow(d),
          if (robust) "MASS::rlm MM, normal theory" else "observed cases, residual df")
}

est_random <- function(spec, fam, random) {
  lab <- sprintf("MMRM with %s as a random intercept", random)
  if (!requireNamespace("nlme", quietly = TRUE)) return(est_row(spec, lab, fam, NA, NA, NA, NA, NA, "nlme not installed"))
  if (!random %in% names(spec$data)) stop("random variable not in data: ", random)
  covs <- spec$covariates[!vapply(spec$covariates, function(tm) random %in% all.vars(stats::reformulate(tm)), TRUE)]
  d <- est_data(spec, c(covs, random)); sub <- spec$subject; vis <- spec$visit; trt <- spec$treatment
  d$.visnum <- as.numeric(d[[vis]]); d$.grp <- factor(d[[random]])
  f <- stats::reformulate(c(covs, trt, vis, paste0(trt, ":", vis)), response = spec$response)
  grp_form <- function(lead) stats::as.formula(paste("~", lead, "| .grp /", sub))
  corr <- switch(spec$covariance, us = nlme::corSymm(form = grp_form(".visnum")), ar1 = , ar1h = nlme::corAR1(form = grp_form(".visnum")),
                 cs = , csh = nlme::corCompSymm(form = grp_form("1")), NULL)
  wts <- if (spec$covariance %in% c("us", "ar1h", "csh")) nlme::varIdent(form = stats::as.formula(paste("~ 1 |", vis))) else NULL
  fit <- tryCatch(nlme::lme(f, data = d, random = ~ 1 | .grp, correlation = corr, weights = wts, method = "REML",
                            control = nlme::lmeControl(maxIter = 200, msMaxIter = 200, opt = "optim")), error = function(e) NULL)
  if (is.null(fit)) return(est_row(spec, lab, fam, NA, NA, NA, NA, NA, "lme did not converge"))
  b <- nlme::fixef(fit); V <- stats::vcov(fit)
  L <- lsmean_L(stats::delete.response(stats::terms(f)), d, spec, names(b))
  est_row(spec, lab, fam, sum(L * b), sqrt(as.numeric(t(L) %*% V %*% L)), NA_real_, nlevels(d[[sub]]), nrow(d),
          sprintf("nlme::lme, %s within subject, normal theory", spec$covariance))
}

est_clda <- function(spec, fam, baseline) {
  lab <- "cLDA, baseline as an outcome"
  if (!baseline %in% names(spec$data)) stop("baseline variable not in data: ", baseline)
  sub <- spec$subject; vis <- spec$visit; trt <- spec$treatment; y <- spec$response
  covs <- spec$covariates[!vapply(spec$covariates, function(tm) baseline %in% all.vars(stats::reformulate(tm)) || vis %in% all.vars(stats::reformulate(tm)), TRUE)]
  d <- est_data(spec, c(covs, baseline)); cov_vars <- if (length(covs)) all.vars(stats::reformulate(covs)) else character()
  # subject-level covariates only: the baseline row has no visit-level values
  keep_sl <- vapply(cov_vars, function(v) all(tapply(d[[v]], d[[sub]], function(x) length(unique(x)) == 1L)), TRUE)
  if (any(!keep_sl)) { drop <- cov_vars[!keep_sl]; covs <- covs[!vapply(covs, function(tm) any(drop %in% all.vars(stats::reformulate(tm))), TRUE)] }
  first <- d[!duplicated(d[[sub]]), , drop = FALSE]
  bl <- first; bl$.aval <- first[[baseline]]; bl$.tv <- "BL"; bl$.vis <- 0
  post <- d; post$.aval <- d[[baseline]] + d[[y]]; post$.tv <- paste(as.character(d[[trt]]), as.character(d[[vis]]), sep = "_"); post$.vis <- as.numeric(d[[vis]])
  cols <- c(sub, trt, all.vars(stats::reformulate(c(covs, "1"))), ".aval", ".tv", ".vis"); cols <- intersect(unique(cols), names(bl))
  x <- rbind(bl[, cols, drop = FALSE], post[, cols, drop = FALSE])
  x$.tv <- factor(x$.tv); x$.vis <- factor(x$.vis, levels = sort(unique(x$.vis))); x[[sub]] <- factor(x[[sub]])
  x <- x[order(x[[sub]], x$.vis), ]
  f <- stats::reformulate(c(".tv", covs), response = ".aval")
  ff <- stats::as.formula(paste(".aval ~", paste(c(".tv", covs, paste0("us(.vis | ", sub, ")")), collapse = " + ")), env = globalenv())
  fit <- tryCatch(mmrm::mmrm(ff, data = x, reml = TRUE, control = mmrm::mmrm_control(method = "Satterthwaite")), error = function(e) NULL)
  if (is.null(fit)) return(est_row(spec, lab, fam, NA, NA, NA, NA, NA, "cLDA mmrm did not converge"))
  lv <- spec$treatment_levels; cells <- paste(lv, spec$contrast_visit, sep = "_")
  if (!all(cells %in% levels(x$.tv))) return(est_row(spec, lab, fam, NA, NA, NA, NA, NA, "contrast visit not estimable"))
  tt <- stats::delete.response(stats::terms(f)); cl <- cov_vars[vapply(cov_vars, function(v) is.factor(x[[v]]), TRUE)]; co <- setdiff(cov_vars, cl)
  grid_list <- lapply(stats::setNames(cl, cl), function(v) levels(droplevels(x[[v]]))); grid_list$.tv <- cells
  grid <- expand.grid(grid_list, stringsAsFactors = FALSE)
  for (v in cl) grid[[v]] <- factor(grid[[v]], levels = levels(x[[v]])); grid$.tv <- factor(grid$.tv, levels = levels(x$.tv))
  for (v in co) grid[[v]] <- mean(x[[v]], na.rm = TRUE)
  X <- stats::model.matrix(tt, grid)[, names(stats::coef(fit, complete = FALSE)), drop = FALSE]
  L <- colMeans(X[grid$.tv == cells[2], , drop = FALSE]) - colMeans(X[grid$.tv == cells[1], , drop = FALSE])
  z <- tryCatch(mmrm::df_1d(fit, L), error = function(e) NULL)
  if (is.null(z)) return(est_row(spec, lab, fam, NA, NA, NA, NA, NA, "cLDA contrast failed"))
  est_row(spec, lab, fam, z$est, z$se, z$df, nlevels(x[[sub]]), nrow(x), "common baseline mean, unstructured covariance over baseline and visits, Satterthwaite")
}
