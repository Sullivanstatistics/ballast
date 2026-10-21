#' Expected behaviour of a result under re-analysis
#'
#' First-order approximations of how often one re-analysis crosses the
#' significance level, and how often it leaves the pre-specified confidence
#' interval, when the re-analysis moves the result by a small random amount.
#'
#' A re-analysis is modelled as moving the test statistic from \eqn{z} to
#' \eqn{z + \tau U} with \eqn{U} standard normal, and the estimate by
#' \eqn{\tau_e U} pre-specified standard errors. Then
#' * the probability of a crossing depends on the distance between \eqn{|z|}
#'   and the critical value \eqn{c}: for a significant result it is
#'   \eqn{\Phi((c - |z|)/\tau) - \Phi((-c - |z|)/\tau)}, which is one half at
#'   \eqn{p = \alpha} whatever the true effect;
#' * the probability of leaving the interval, \eqn{2\Phi(-c/\tau_e)}, does not
#'   depend on \eqn{z} at all, and is negligible for the perturbation scales of
#'   model choices (about 0.3 to 0.4 standard errors).
#'
#' The contrast between the two is the argument for defining fragility by the
#' interval: crossings measure where the p-value happens to sit, while exits
#' from the interval need a perturbation large enough to matter. The
#' approximation ignores changes in the standard error and the correlation
#' between re-analyses; the simulation studies in the methods paper check it.
#'
#' @param p Pre-specified two-sided p-value(s).
#' @param tau Perturbation scale: the standard deviation of the shift in the
#'   test statistic (for `expected_crossing()`) or in the estimate measured in
#'   pre-specified standard errors (for `expected_exit()`).
#' @param alpha Two-sided significance level.
#' @param level Confidence level of the pre-specified interval.
#' @return A numeric vector of probabilities per re-analysis.
#' @examples
#' # A filed p of 0.029 and a model-choice perturbation of 0.3 SE
#' expected_crossing(0.029, tau = 0.3)
#' # The same perturbation almost never leaves the interval
#' expected_exit(tau = 0.3)
#' # Crossing probability across the p-value range
#' round(expected_crossing(c(0.0001, 0.001, 0.01, 0.025, 0.05, 0.1, 0.5), tau = 0.3), 3)
#' @export
expected_crossing <- function(p, tau, alpha = 0.05) {
  if (any(p <= 0 | p > 1, na.rm = TRUE)) stop("p must be in (0, 1]")
  if (any(tau <= 0, na.rm = TRUE)) stop("tau must be positive")
  z <- stats::qnorm(1 - p / 2); crit <- stats::qnorm(1 - alpha / 2)
  inside <- stats::pnorm((crit - z) / tau) - stats::pnorm((-crit - z) / tau)
  ifelse(p < alpha, inside, 1 - inside)
}

#' @rdname expected_crossing
#' @export
expected_exit <- function(tau, level = 0.95) {
  if (any(tau <= 0, na.rm = TRUE)) stop("tau must be positive")
  2 * stats::pnorm(-stats::qnorm(1 - (1 - level) / 2) / tau)
}
