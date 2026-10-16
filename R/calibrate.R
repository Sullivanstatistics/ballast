#' Simulate a two-arm longitudinal trial
#'
#' Multivariate-normal responses at `n_visits` post-baseline visits with an
#' AR(1) correlation, a baseline covariate, a treatment effect growing
#' linearly to `delta` at the last visit, and dropout after each visit whose
#' probability rises as the current value falls (missing at random).
#'
#' @param n_per_arm Subjects per arm.
#' @param delta Treatment effect at the last visit (active minus reference).
#' @param n_visits Number of post-baseline visits.
#' @param sigma Residual standard deviation at each visit.
#' @param rho AR(1) correlation between adjacent visits.
#' @param dropout Baseline per-visit dropout probability.
#' @param baseline_beta Slope of the response on the baseline covariate.
#' @param seed Random seed.
#' @return A long data frame with `id`, `arm` (`"REF"`, `"ACT"`), `base`,
#'   `visit` (`"V1"`, ...) and `y`, missing rows removed.
#' @examples
#' d <- simulate_trial(40, delta = 3, seed = 1); head(d)
#' @export
simulate_trial <- function(n_per_arm = 50, delta = 0, n_visits = 4, sigma = 10, rho = 0.6, dropout = 0.08, baseline_beta = 0.5, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  n <- 2 * n_per_arm; arm <- rep(c("REF", "ACT"), each = n_per_arm); base <- stats::rnorm(n, 50, 10)
  R <- rho^abs(outer(seq_len(n_visits), seq_len(n_visits), "-")); L <- chol(R)
  eps <- matrix(stats::rnorm(n * n_visits), n) %*% L * sigma
  mu <- outer(baseline_beta * (base - 50), rep(1, n_visits)) + outer(arm == "ACT", delta * seq_len(n_visits) / n_visits)
  Y <- mu + eps
  if (n_visits > 1) for (v in 2:n_visits) { z <- (Y[, v - 1] - mean(Y[, v - 1], na.rm = TRUE)) / sigma; p <- stats::plogis(stats::qlogis(dropout) - 0.8 * z)
    gone <- is.na(Y[, v - 1]) | stats::runif(n) < p; Y[gone, v:n_visits] <- NA }
  d <- data.frame(id = rep(sprintf("S%04d", seq_len(n)), each = n_visits), arm = rep(arm, each = n_visits), base = rep(base, each = n_visits),
                  visit = rep(sprintf("V%d", seq_len(n_visits)), n), y = as.vector(t(Y)), stringsAsFactors = FALSE)
  d[!is.na(d$y), , drop = FALSE]
}

#' Pre-trial calibration of the stress test
#'
#' Simulates trials from a planned design and runs a light stress test on
#' each (covariance, inference, covariate, weighting and leave-one-out
#' families, plus the greedy deletion search if `fragility = TRUE`), so that
#' a sponsor can see, before unblinding, how often a trial of this design
#' would be classed robust, sensitive or fragile at each power, and how often
#' the marginal flag would be set.
#'
#' @inheritParams simulate_trial
#' @param power Target powers for the pre-specified analysis; the effect size
#'   giving each is derived from the design (0 gives the null).
#' @param n_trials Trials per power.
#' @param fragility Run the deletion search (slower).
#' @param cores Worker processes (the trials are distributed, so each trial's
#'   families run on one core).
#' @param seed Base seed.
#' @return A data frame of class `stress_calibration` with one row per power:
#'   the effect size, observed power, and the proportion of trials with each
#'   verdict, the marginal flag, and (if run) a one-subject fragility;
#'   `attr(, "trials")` holds the per-trial rows.
#' @examples
#' \donttest{stress_calibrate(n_per_arm = 20, power = c(0, 0.8), n_trials = 2)}
#' @export
stress_calibrate <- function(n_per_arm = 50, power = c(0, 0.5, 0.8, 0.95), n_trials = 100, n_visits = 4, sigma = 10, rho = 0.6, dropout = 0.08,
                             baseline_beta = 0.5, fragility = FALSE, cores = 1L, seed = 1) {
  n_eff <- n_per_arm * (1 - dropout)^(n_visits - 1); r2 <- (baseline_beta * 10)^2 / ((baseline_beta * 10)^2 + sigma^2)
  delta_for <- function(pw) if (pw == 0) 0 else (stats::qnorm(0.975) + stats::qnorm(pw)) * sigma * sqrt(2 / n_eff) * sqrt(1 - r2)
  jobs <- do.call(c, lapply(seq_along(power), function(s) lapply(seq_len(n_trials), function(i) list(power = power[s], delta = delta_for(power[s]), seed = seed + 100000 * s + i))))
  one <- function(job) {
    d <- simulate_trial(n_per_arm, job$delta, n_visits, sigma, rho, dropout, baseline_beta, seed = job$seed)
    spec <- stress_spec(d, "y", "id", "visit", "arm", "REF", covariates = ~ base, covariance = "us", method = "Satterthwaite", vcov = "Asymptotic")
    base <- stress_fit(spec); if (!base$converged) return(NULL)
    rows <- list(stress_covariance(spec, c("us", "ar1h", "cs")), stress_inference(spec, default_inference()[c("Satterthwaite", "Kenward-Roger (linear)", "Sandwich, between-within")]),
                 stress_covariates(spec), stress_weights(spec), stress_loo(spec))
    cen <- do.call(stress_census, c(list(spec = spec), rows, list(base = base))); v <- stress_verdict(cen)
    fk <- if (fragility) { a <- attr(stress_fragility(spec, "significance", max_k = 3), "fragility"); if (a$reached) a$k else NA_integer_ } else NA_integer_
    data.frame(power = job$power, delta = job$delta, seed = job$seed, base_p = base$p, significant = base$p < 0.05, stability = v$stability, marginal = v$marginal,
               crossed = v$n_crossed, max_shift_se = v$max_shift_se, frag_k = fk, stringsAsFactors = FALSE)
  }
  res <- if (cores > 1L) { cl <- parallel::makeCluster(cores); on.exit(parallel::stopCluster(cl), add = TRUE)
    parallel::clusterEvalQ(cl, { requireNamespace("mmrmstress", quietly = TRUE); NULL }); parallel::clusterExport(cl, "one", envir = environment())
    parallel::parLapplyLB(cl, jobs, function(j) tryCatch(one(j), error = function(e) NULL)) } else lapply(jobs, function(j) tryCatch(one(j), error = function(e) NULL))
  trials <- do.call(rbind, res[!vapply(res, is.null, TRUE)])
  out <- do.call(rbind, lapply(split(trials, trials$power), function(g) data.frame(
    power_target = g$power[1], delta = g$delta[1], trials = nrow(g), power_observed = mean(g$significant), marginal = mean(g$marginal),
    robust = mean(g$stability == "robust"), sensitive = mean(g$stability == "sensitive"), fragile = mean(g$stability == "fragile"),
    sensitive_given_sig = if (any(g$significant)) mean(g$stability[g$significant] == "sensitive") else NA_real_,
    fragile_k1_given_sig = if (fragility && any(g$significant)) mean(g$frag_k[g$significant] == 1, na.rm = TRUE) else NA_real_)))
  rownames(out) <- NULL
  structure(out, class = c("stress_calibration", "data.frame"), trials = trials, design = list(n_per_arm = n_per_arm, n_visits = n_visits, sigma = sigma, rho = rho, dropout = dropout))
}

#' @export
print.stress_calibration <- function(x, ...) {
  d <- attr(x, "design")
  cat(sprintf("Stress-test calibration: %d per arm, %d visits, SD %s, AR(1) %s, dropout %s per visit\n", d$n_per_arm, d$n_visits, format(d$sigma), format(d$rho), format(d$dropout)))
  print(as.data.frame(x), row.names = FALSE, digits = 3); invisible(x)
}
