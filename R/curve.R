#' Perturbation family: a curve over a continuous data perturbation
#'
#' Applies a user-supplied modification to the spec's data at each value of a
#' continuous parameter, refits the pre-specified model and returns one row
#' per value with the value in `param`. This generalises tipping-point
#' searches that are not multiple-imputation based: assigning a contested
#' participant a post-deviation trajectory, shifting one arm's observed
#' values, moving a baseline definition, and so on. Rows are
#' `kind = "search"` except the row at `anchor`, which is a counted
#' alternative.
#'
#' @inheritParams stress_covariance
#' @param values Numeric vector of parameter values.
#' @param modify A function `function(data, value)` returning a data frame in
#'   the spec's layout. It receives the spec's own data.
#' @param family Family label for the rows.
#' @param anchor The parameter value (if any) that represents an alternative
#'   analysis in its own right rather than a search point; `NULL` for none.
#' @param role `"sensitivity"` or `"supplementary"`; see [stress_fit()].
#' @return A `stress_rows` data frame, one row per value, with `param` set.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL)
#' # shift every observed value of one subject on the active arm
#' shift_pt3 <- function(d, v) { k <- d$USUBJID == "PT3"; d$FEV1[k] <- d$FEV1[k] + v; d }
#' cv <- stress_curve(spec, values = c(-20, -10, 0, 10, 20), modify = shift_pt3, anchor = 0)
#' tipping_point(cv)
#' @export
stress_curve <- function(spec, values, modify, family = "perturbation curve", anchor = NULL, role = "sensitivity", cores = 1L) {
  check_spec(spec); force_args()
  if (!is.function(modify)) stop("modify must be a function(data, value)")
  values <- as.numeric(values)
  bind_rows_(stress_map(values, function(v) {
    d <- modify(spec$data, v)
    r <- stress_fit(spec, data = d, label = sprintf("%s = %s", family, format(v)), family = family,
                    kind = if (!is.null(anchor) && isTRUE(v == anchor)) "alternative" else "search", is_base = FALSE, role = role)
    r$param <- v; r
  }, cores))
}

#' Find where a p-value curve crosses alpha
#'
#' For rows that carry a `param` value (from [stress_tipping()] or
#' [stress_curve()]), interpolates linearly between adjacent parameter values
#' to find where the p-value crosses `alpha`, separately for each family.
#'
#' @param rows A `stress_rows` data frame or a `stress_census`.
#' @param alpha Significance level; defaults to the rows' own `alpha`.
#' @return A data frame with one row per family: `family`, `n` points,
#'   `param_min`, `param_max`, `p_min`, `p_max`, `crossing` (the interpolated
#'   parameter value, `NA` when the curve does not cross) and `direction`
#'   (`"up"` when p rises through alpha with increasing parameter, `"down"`
#'   otherwise).
#' @export
tipping_point <- function(rows, alpha = NULL) {
  x <- as.data.frame(rows); x <- x[!is.na(x$param) & !is.na(x$p), , drop = FALSE]
  if (!nrow(x)) stop("no rows with a param value")
  if (is.null(alpha)) alpha <- x$alpha[1]
  do.call(rbind, lapply(split(x, x$family), function(g) {
    g <- g[order(g$param), ]; p <- g$p; v <- g$param
    i <- which(diff(sign(p - alpha)) != 0)[1]
    cr <- if (is.na(i)) NA_real_ else v[i] + (alpha - p[i]) * (v[i + 1] - v[i]) / (p[i + 1] - p[i])
    data.frame(family = g$family[1], n = nrow(g), param_min = min(v), param_max = max(v), p_min = min(p), p_max = max(p),
               crossing = cr, direction = if (is.na(i)) NA_character_ else if (p[i + 1] > p[i]) "up" else "down", stringsAsFactors = FALSE)
  }))
}
