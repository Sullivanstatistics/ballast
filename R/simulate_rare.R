#' Simulate a small trial with rare-disease features
#'
#' Draws a two-arm longitudinal trial with the features that make small
#' trials in rare disease hard to read: few participants, heterogeneous
#' progression (a mixture of fast and slow progressors with a random slope),
#' an effect that varies with progression, sites, dropout, and optionally one
#' planted defect. It is the data generator of the simulation studies in the
#' methods paper and complements [simulate_trial()], which it leaves unchanged.
#'
#' The response is a change score at visits 1 to `n_visits`. For participant
#' *i* at visit *v*, with \eqn{t_v = v / V},
#' \deqn{y_{iv} = \beta (b_i - 50) + (d_i + s_i + u_{site(i)}) t_v + T_i e_i t_v + \epsilon_{iv},}
#' where \eqn{b_i} is the baseline, \eqn{d_i} the extra decline of a fast
#' progressor, \eqn{s_i} a random slope, \eqn{u} a site effect, \eqn{T_i} the
#' active-arm indicator, \eqn{e_i} the participant's treatment effect and
#' \eqn{\epsilon} AR(1) errors with standard deviation `sigma`.
#'
#' Populations:
#' * `"homogeneous"`: no progression heterogeneity; `fast` is recorded but is
#'   not prognostic, so models with and without it target the same effect.
#' * `"mixture"`: a fraction `fast_frac` of fast progressors lose a further
#'   `fast_decline` points by the last visit; random slope with SD `slope_sd`;
#'   the effect is `fast_effect` times larger in fast progressors, scaled so
#'   that the average effect is `delta`.
#' * `"heavy"`: as homogeneous with Student-t errors on `t_df` degrees of
#'   freedom, scaled to the same standard deviation.
#'
#' Defects (each makes a significant result one that should not be trusted):
#' * `"outlier"`: `n_outliers` active-arm participants shifted up by
#'   `outlier_size` standard deviations at every visit (a data error).
#' * `"site"`: the treatment effect `delta` applies at site 1 only.
#' * `"mnar"`: active-arm dropout also depends on the unobserved next value,
#'   so participants about to decline leave (informative dropout), with a
#'   baseline dropout rate of `mnar_dropout` per visit.
#' * `"allocation"`: allocation is not independent of prognosis (for example a
#'   stratification error or selection at enrolment). Participants are drawn
#'   into the active arm with weight `fast_to_active` for fast progressors and
#'   `1 - fast_to_active` for slow ones, so with `fast_to_active < 0.5` fast
#'   progressors (who decline more in the `"mixture"` population) gather in
#'   the reference arm. An analysis that omits `fast` is then biased in favour
#'   of the active arm; one that adjusts for it is not.
#'
#' @param n_per_arm Participants per arm (exactly balanced).
#' @param delta Average treatment effect at the last visit (higher is better).
#' @param n_visits,sigma,rho Visits, residual SD and AR(1) correlation.
#' @param dropout Missing-at-random dropout probability per visit.
#' @param baseline_beta Slope of the response on the baseline.
#' @param population `"homogeneous"`, `"mixture"` or `"heavy"`.
#' @param fast_frac,fast_decline,slope_sd,fast_effect Mixture settings.
#' @param t_df Degrees of freedom of the heavy-tailed errors.
#' @param n_sites,site_sd Number of sites and SD of the site effect on
#'   progression.
#' @param defect `"none"`, `"outlier"`, `"site"`, `"mnar"` or `"allocation"`.
#' @param n_outliers,outlier_size Outlier settings (size in units of `sigma`).
#' @param mnar_strength,mnar_dropout Informative-dropout settings.
#' @param fast_to_active Allocation-defect setting: the weight with which a
#'   fast progressor is drawn into the active arm (slow progressors get
#'   `1 - fast_to_active`); 0.5 is fair allocation.
#' @param seed Random seed; the caller's random-number state is restored. The
#'   draws use R's default generators whatever the caller's `RNGkind()`, so a
#'   seed gives the same trial in a plain session and on parallel workers.
#' @return A data frame in long format with one row per observed visit:
#'   `id`, `arm` (`"REF"` or `"ACT"`), `site`, `base`, `fast` (0/1), `visit`
#'   (`"V1"`, ...) and `y`.
#' @examples
#' d <- simulate_rare_trial(n_per_arm = 20, delta = 5, population = "mixture", seed = 1)
#' head(d)
#' spec <- stress_spec(d, "y", "id", "visit", "arm", "REF", covariates = ~ base + fast)
#' stress_fit(spec)[, c("estimate", "stderr", "p")]
#' @seealso [simulate_trial()]; [expected_crossing()] for the analytic
#'   crossing rates the simulations check.
#' @export
simulate_rare_trial <- function(n_per_arm = 25, delta = 0, n_visits = 4, sigma = 10, rho = 0.6, dropout = 0.03, baseline_beta = 0.5,
                                population = c("homogeneous", "mixture", "heavy"), fast_frac = 0.35, fast_decline = 8, slope_sd = 4,
                                fast_effect = 1.6, t_df = 3, n_sites = 8, site_sd = 2.5, defect = c("none", "outlier", "site", "mnar", "allocation"),
                                n_outliers = 1, outlier_size = 10, mnar_strength = 1.5, mnar_dropout = 3 * dropout, fast_to_active = 0.25,
                                seed = NULL) {
  population <- match.arg(population); defect <- match.arg(defect)
  if (fast_frac * fast_effect >= 1) stop("fast_frac * fast_effect must be below 1 so the slow-progressor effect stays positive")
  if (!is.null(seed)) { old_rng <- rng_state(); on.exit(rng_restore(old_rng), add = TRUE); seed_rng(seed) }
  n <- 2 * n_per_arm; V <- n_visits; tv <- seq_len(V) / V
  arm <- sample(rep(c("REF", "ACT"), each = n_per_arm)); act <- arm == "ACT"
  site <- sample(seq_len(n_sites), n, replace = TRUE)
  base <- stats::rnorm(n, 50, 10); fast <- stats::rbinom(n, 1, fast_frac)
  if (defect == "allocation") {
    if (fast_to_active <= 0 || fast_to_active >= 1) stop("fast_to_active must be between 0 and 1")
    on_active <- sample(n, n_per_arm, prob = ifelse(fast == 1, fast_to_active, 1 - fast_to_active))
    arm <- ifelse(seq_len(n) %in% on_active, "ACT", "REF"); act <- arm == "ACT"
  }
  mixture <- population == "mixture"
  decline <- if (mixture) -fast_decline * fast else rep(0, n)
  slope <- if (mixture) stats::rnorm(n, 0, slope_sd) else rep(0, n)
  u <- stats::rnorm(n_sites, 0, site_sd)[site]
  slow_effect <- (1 - fast_frac * fast_effect) / (1 - fast_frac)        # so that the average multiplier is 1
  eff <- if (mixture) delta * ifelse(fast == 1, fast_effect, slow_effect) else rep(delta, n)
  if (defect == "site") eff <- ifelse(site == 1, delta, 0)
  L <- chol(rho^abs(outer(seq_len(V), seq_len(V), "-")))
  Z <- if (population == "heavy") matrix(stats::rt(n * V, t_df) / sqrt(t_df / (t_df - 2)), n) else matrix(stats::rnorm(n * V), n)
  Y <- outer(baseline_beta * (base - 50), rep(1, V)) + outer(decline + slope + u, tv) + outer(ifelse(act, eff, 0), tv) + (Z %*% L) * sigma
  if (defect == "outlier") { who <- sample(which(act), n_outliers); Y[who, ] <- Y[who, ] + outlier_size * sigma }
  if (V > 1) for (v in 2:V) {
    z_prev <- (Y[, v - 1] - mean(Y[, v - 1], na.rm = TRUE)) / sigma
    z_next <- (Y[, v] - mean(Y[, v], na.rm = TRUE)) / sigma
    lin <- stats::qlogis(dropout) - 0.8 * z_prev
    if (defect == "mnar") lin <- stats::qlogis(mnar_dropout) - 0.8 * z_prev - ifelse(act, mnar_strength * z_next, 0)
    gone <- is.na(Y[, v - 1]) | stats::runif(n) < stats::plogis(lin)
    Y[gone, v:V] <- NA
  }
  d <- data.frame(id = rep(sprintf("S%04d", seq_len(n)), each = V), arm = rep(arm, each = V), site = rep(sprintf("site%d", site), each = V),
                  base = rep(base, each = V), fast = rep(fast, each = V), visit = rep(sprintf("V%d", seq_len(V)), n), y = as.vector(t(Y)),
                  stringsAsFactors = FALSE)
  d <- d[!is.na(d$y), , drop = FALSE]; rownames(d) <- NULL
  d
}
