#' Size a trial for a robust result
#'
#' Simulates trials from a planned design over a grid of sample sizes and
#' effect sizes, runs the light stress test on each (covariance, inference,
#' covariate, weighting and leave-one-subject-out families) and reports, for
#' every cell, the conventional power next to the robustness power: the
#' probability that the pre-specified analysis is significant and classed
#' robust. The deletion search and a delta-adjusted tipping grid are optional
#' and give the expected fragility index and the shift the result can absorb.
#' This is the design-stage use of the stress test: choose the sample size so
#' that a true effect is expected to come out robust rather than only
#' significant, and write the expected verdict rates into the statistical
#' analysis plan before unblinding so that the observed verdict has a
#' pre-registered comparison.
#'
#' The light family set offers the alternative covariance structures, three
#' inference methods, the model without the baseline covariate, observed-margin
#' weighting and, if `loo = TRUE`, every single-subject deletion. Deletions
#' dominate the run time at large sample sizes; `loo = FALSE` gives a fast
#' first pass whose verdicts omit the deletion family.
#'
#' @inheritParams simulate_trial
#' @param n_per_arm Subjects per arm to evaluate (a vector).
#' @param delta Treatment effects at the last visit to evaluate (a vector);
#'   include 0 to see the null.
#' @param n_trials Trials per cell.
#' @param covariance,method,vcov The pre-specified analysis model, as in
#'   [stress_spec()].
#' @param alpha Two-sided significance level.
#' @param alternatives Covariance structures offered as alternatives; the
#'   pre-specified one is removed from the set.
#' @param loo Run the leave-one-subject-out family.
#' @param fragility Run the greedy deletion search for significance up to
#'   `max_k` removals (slow). Otherwise a one-subject loss of significance is
#'   read from the leave-one-out rows.
#' @param max_k Removals allowed in the deletion search.
#' @param tipping Run a delta-adjusted tipping grid (imputed active-arm values
#'   shifted down) and record the shift at which `p` crosses `alpha`.
#' @param shifts Shifts for the tipping grid as multiples of `delta` (of
#'   `sigma` when `delta` is 0).
#' @param m Imputations per shift.
#' @param cores Worker processes. Trials are distributed, so each trial's
#'   families run on one core.
#' @param seed Base seed; every trial's seed is derived from it.
#' @return A data frame of class `stress_design` with one row per cell:
#'   `n_per_arm`, `delta`, `trials`, `power` (proportion significant),
#'   `robustness_power` (significant and robust), `robust_given_sig`,
#'   `sensitive_given_sig`, `fragile_given_sig`, `marginal_given_sig`,
#'   `k1_given_sig` (one deletion loses significance), `k_reached_given_sig`
#'   and `k_median` (deletion search, if run), `tipping_margin` (median shift
#'   that crosses `alpha` among significant trials, as a multiple of `delta`
#'   or `sigma`) and `tipping_absorbed` (share of significant trials with no
#'   crossing within the grid), and `max_shift_se` (median largest shift in
#'   pre-specified standard errors). `attr(, "trials")` holds the per-trial
#'   rows and `attr(, "design")` the settings. [plot.stress_design()] draws
#'   power and robustness power against the sample size.
#' @examples
#' \donttest{
#' des <- stress_design(n_per_arm = c(40, 80), delta = c(0, 5), n_trials = 4, loo = FALSE)
#' des
#' }
#' @seealso [stress_calibrate()] for the verdict rates of one design at a set
#'   of planned powers; [stress_sap()] for the analysis-plan text.
#' @export
stress_design <- function(n_per_arm, delta, n_trials = 100, n_visits = 4, sigma = 10, rho = 0.6, dropout = 0.08, baseline_beta = 0.5,
                          covariance = "us", method = "Satterthwaite", vcov = "Asymptotic", alpha = 0.05,
                          alternatives = c("us", "ar1h", "cs"), loo = TRUE, fragility = FALSE, max_k = 5, tipping = FALSE,
                          shifts = seq(0, 2, by = 0.25), m = 5, errors = "normal", t_df = 3, hetero = 1, mnar = 0, interaction = 0,
                          cores = 1L, seed = 1) {
  force_args()
  n_per_arm <- as.integer(n_per_arm); delta <- as.numeric(delta)
  if (!length(n_per_arm) || any(n_per_arm < 4L)) stop("n_per_arm must be 4 or more")
  grid <- expand.grid(n = n_per_arm, delta = delta, KEEP.OUT.ATTRS = FALSE)
  jobs <- do.call(c, lapply(seq_len(nrow(grid)), function(g) lapply(seq_len(n_trials), function(i)
    list(n = grid$n[g], delta = grid$delta[g], seed = seed + 100000L * g + i))))
  alts <- setdiff(alternatives, covariance)
  infer <- default_inference()[c("Satterthwaite", "Kenward-Roger (linear)", "Sandwich, between-within")]
  one <- function(job) {
    d <- simulate_trial(job$n, job$delta, n_visits, sigma, rho, dropout, baseline_beta, errors = errors, t_df = t_df,
                        hetero = hetero, mnar = mnar, interaction = interaction, seed = job$seed)
    spec <- stress_spec(d, "y", "id", "visit", "arm", "REF", covariates = ~ base, covariance = covariance, method = method, vcov = vcov, alpha = alpha)
    base <- stress_fit(spec); if (!base$converged) return(NULL)
    sig <- base$p < alpha
    rows <- list(stress_inference(spec, infer), stress_covariates(spec), stress_weights(spec))
    if (length(alts)) rows <- c(list(stress_covariance(spec, alts)), rows)
    if (loo) rows <- c(rows, list(stress_loo(spec)))
    cen <- do.call(stress_census, c(list(spec = spec), rows, list(base = base))); v <- stress_verdict(cen)
    k <- NA_integer_
    if (fragility) {
      a <- attr(stress_fragility(spec, "significance", max_k = max_k), "fragility"); if (isTRUE(a$reached)) k <- as.integer(a$k)
    } else if (loo) {
      lo <- as.data.frame(cen); lo <- lo[lo$family == "leave-one-out: subject" & lo$counted & !is.na(lo$p), , drop = FALSE]
      if (nrow(lo) && any((lo$p < alpha) != sig)) k <- 1L
    }
    tip <- NA_real_
    if (tipping && sig) {
      unit <- if (job$delta != 0) abs(job$delta) else sigma
      tr <- stress_tipping(spec, deltas = -shifts * unit, m = m, seed = job$seed)
      tp <- tipping_point(tr, alpha); tip <- abs(tp$crossing[1]) / unit
    }
    data.frame(n_per_arm = job$n, delta = job$delta, seed = job$seed, n_subj = base$n_subj, estimate = base$estimate, stderr = base$stderr,
               p = base$p, significant = sig, stability = v$stability, marginal = v$marginal, crossed = v$n_crossed,
               max_shift_se = v$max_shift_se, frag_k = k, tipping_margin = tip, stringsAsFactors = FALSE)
  }
  res <- if (cores > 1L) {
    cl <- parallel::makeCluster(cores); on.exit(parallel::stopCluster(cl), add = TRUE)
    parallel::clusterEvalQ(cl, { requireNamespace("ballast", quietly = TRUE); NULL })
    parallel::clusterExport(cl, c("one", "n_visits", "sigma", "rho", "dropout", "baseline_beta", "errors", "t_df", "hetero", "mnar", "interaction",
                                  "covariance", "method", "vcov", "alpha", "alts", "infer", "loo", "fragility", "max_k", "tipping", "shifts", "m"), envir = environment())
    parallel::parLapplyLB(cl, jobs, function(j) tryCatch(one(j), error = function(e) NULL))
  } else lapply(jobs, function(j) tryCatch(one(j), error = function(e) NULL))
  trials <- do.call(rbind, res[!vapply(res, is.null, TRUE)])
  if (is.null(trials) || !nrow(trials)) stop("no trial produced a converged base fit")
  cell <- function(g) {
    s <- g$significant; ns <- sum(s); cond <- function(x) if (ns) mean(x[s], na.rm = TRUE) else NA_real_
    data.frame(n_per_arm = g$n_per_arm[1], delta = g$delta[1], trials = nrow(g), power = mean(s),
               robustness_power = mean(s & g$stability == "robust"),
               robust_given_sig = cond(g$stability == "robust"), sensitive_given_sig = cond(g$stability == "sensitive"),
               fragile_given_sig = cond(g$stability == "fragile"), marginal_given_sig = cond(g$marginal),
               k1_given_sig = cond(!is.na(g$frag_k) & g$frag_k == 1L),
               k_reached_given_sig = if (fragility) cond(!is.na(g$frag_k)) else NA_real_,
               k_median = if (fragility && ns && any(!is.na(g$frag_k[s]))) stats::median(g$frag_k[s], na.rm = TRUE) else NA_real_,
               tipping_margin = if (tipping && ns && any(!is.na(g$tipping_margin[s]))) stats::median(g$tipping_margin[s], na.rm = TRUE) else NA_real_,
               tipping_absorbed = if (tipping) cond(is.na(g$tipping_margin)) else NA_real_,
               max_shift_se = stats::median(g$max_shift_se, na.rm = TRUE), stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, lapply(split(trials, list(trials$delta, trials$n_per_arm), drop = TRUE), cell))
  out <- out[order(out$delta, out$n_per_arm), ]; rownames(out) <- NULL
  structure(out, class = c("stress_design", "data.frame"), trials = trials,
            design = list(n_visits = n_visits, sigma = sigma, rho = rho, dropout = dropout, baseline_beta = baseline_beta,
                          covariance = covariance, method = method, vcov = vcov, alpha = alpha, loo = loo, fragility = fragility,
                          tipping = tipping, errors = errors, hetero = hetero, mnar = mnar, interaction = interaction, n_trials = n_trials))
}

#' @rdname stress_design
#' @param x A `stress_design` object.
#' @param target Robustness power to reach; the print method names the
#'   smallest sample size per arm that reaches it for each non-zero effect.
#' @param ... Ignored.
#' @export
print.stress_design <- function(x, target = 0.8, ...) {
  d <- attr(x, "design")
  cat(sprintf("Design stress test: %d trials per cell, %d visits, SD %s, AR(1) %s, dropout %s per visit; model %s / %s / %s; alpha %s\n",
              d$n_trials, d$n_visits, format(d$sigma), format(d$rho), format(d$dropout), d$covariance, d$method, d$vcov, format(d$alpha)))
  cat(sprintf("Families: covariance, inference, covariates, weighting%s%s%s\n", if (d$loo) ", leave-one-subject-out" else "",
              if (d$fragility) ", deletion search" else "", if (d$tipping) ", tipping grid" else ""))
  show <- c("n_per_arm", "delta", "trials", "power", "robustness_power", "robust_given_sig", "sensitive_given_sig", "fragile_given_sig", "marginal_given_sig", "k1_given_sig")
  if (d$fragility) show <- c(show, "k_reached_given_sig", "k_median")
  if (d$tipping) show <- c(show, "tipping_margin", "tipping_absorbed")
  print(as.data.frame(x)[, c(show, "max_shift_se")], row.names = FALSE, digits = 3)
  for (dl in unique(x$delta[x$delta != 0])) {
    g <- x[x$delta == dl, ]; ok <- g$n_per_arm[g$robustness_power >= target]
    cat(if (length(ok)) sprintf("Effect %s: smallest n per arm with robustness power >= %s is %d (power %.2f, robustness power %.2f)\n", format(dl), format(target), min(ok),
                                g$power[g$n_per_arm == min(ok)], g$robustness_power[g$n_per_arm == min(ok)])
        else sprintf("Effect %s: no sample size in the grid reaches robustness power %s (largest %.2f at n = %d)\n", format(dl), format(target), max(g$robustness_power), g$n_per_arm[which.max(g$robustness_power)]))
  }
  invisible(x)
}

#' Plot power and robustness power against the sample size
#'
#' @param x A `stress_design` object from [stress_design()].
#' @param target Reference line for the robustness power.
#' @param ... Ignored.
#' @return A ggplot: the probability of a significant result and of a
#'   significant and robust result against subjects per arm, one panel per
#'   effect size.
#' @export
plot.stress_design <- function(x, target = 0.8, ...) {
  need_ggplot()
  z <- as.data.frame(x)
  long <- rbind(data.frame(n_per_arm = z$n_per_arm, delta = z$delta, what = "Significant", prob = z$power),
                data.frame(n_per_arm = z$n_per_arm, delta = z$delta, what = "Significant and robust", prob = z$robustness_power))
  long$what <- factor(long$what, c("Significant", "Significant and robust"))
  long$panel <- factor(sprintf("Effect at the last visit = %s", format(long$delta)), unique(sprintf("Effect at the last visit = %s", format(sort(unique(long$delta))))))
  g <- ggplot2::ggplot(long, ggplot2::aes(x = n_per_arm, y = prob, colour = what)) +
    ggplot2::geom_hline(yintercept = target, colour = PAL[["orange"]], linetype = "22") +
    ggplot2::geom_line(linewidth = 1) + ggplot2::geom_point(size = 2.4) +
    ggplot2::scale_colour_manual(values = c(PAL[["blue"]], PAL[["navy"]])) +
    ggplot2::scale_y_continuous(limits = c(0, 1), labels = function(v) paste0(round(100 * v), "%")) +
    ggplot2::labs(x = "Subjects per arm", y = "Probability", colour = NULL) +
    ggplot2::theme_minimal(base_size = 11) + ggplot2::theme(legend.position = "bottom", panel.grid.minor = ggplot2::element_blank())
  if (length(unique(long$delta)) > 1L) g <- g + ggplot2::facet_wrap(~panel)
  g
}

utils::globalVariables(c("n_per_arm", "prob", "what"))
