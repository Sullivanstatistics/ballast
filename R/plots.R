# Display functions. ggplot2 is a suggested package; every function checks for it.
need_ggplot <- function() if (!requireNamespace("ggplot2", quietly = TRUE)) stop("ggplot2 is needed for plotting")

PAL <- c(ink = "#111111", ink2 = "#5a6273", grey = "#7f7f78", light = "#c9c9c3", blue = "#2a78d6", navy = "#1e3a66",
         orange = "#e8873a", band = "#e6eaf3", grid = "#e6e8ee")

#' Plot p-value curves over a continuous perturbation
#'
#' Draws the p-value against the parameter for every family of rows that
#' carries a `param` value (from [stress_tipping()] or [stress_curve()]): one
#' line per family, the alpha reference line, the anchor point (the row of
#' `kind = "alternative"`, usually the unshifted analysis) emphasised, and a
#' dotted vertical line at each interpolated crossing with its value.
#'
#' Given a named list (one element per endpoint-metric row, say), it draws one
#' panel per element, with the crossings found within each panel.
#'
#' @param rows A `stress_rows` data frame, a `stress_census` or a `stress_result`;
#'   or a named list of these, one panel each. Rows without a `param` are ignored.
#' @param alpha Significance level; defaults to the rows' own `alpha`.
#' @param xlab,ylab Axis labels.
#' @param log_p Draw the p-value axis on a log scale.
#' @param ncol Number of columns of panels when `rows` is a list.
#' @return A `ggplot` object.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:80), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL)
#' tp <- stress_tipping(spec, deltas = c(0, -4, -8), m = 3)
#' if (requireNamespace("ggplot2", quietly = TRUE)) plot_pcurve(tp)
#' \donttest{
#' tp4 <- stress_tipping(spec, deltas = c(0, -4, -8), m = 3, shift_visits = "VIS4")
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   plot_pcurve(list("Every visit" = tp, "Visit 4 only" = tp4))
#' }
#' }
#' @export
plot_pcurve <- function(rows, alpha = NULL, xlab = "Perturbation", ylab = "p-value", log_p = FALSE, ncol = 1) {
  need_ggplot()
  as_rows <- function(z) if (inherits(z, "stress_result")) as.data.frame(z$census) else as.data.frame(z)
  faceted <- is.list(rows) && !is.data.frame(rows) && !inherits(rows, "stress_result")
  if (faceted) {
    if (is.null(names(rows)) || !all(nzchar(names(rows)))) stop("a list of rows must be named, one name per panel")
    x <- do.call(rbind, lapply(names(rows), function(nm) { z <- as_rows(rows[[nm]]); z <- z[!is.na(z$param) & !is.na(z$p), , drop = FALSE]
      if (nrow(z)) cbind(z[, c("family", "kind", "param", "p", "alpha")], panel = nm, stringsAsFactors = FALSE) }))
    if (is.null(x)) stop("no rows with a param value")
    x$panel <- factor(x$panel, levels = names(rows))
  } else {
    x <- as_rows(rows); x <- x[!is.na(x$param) & !is.na(x$p), , drop = FALSE]
    if (!nrow(x)) stop("no rows with a param value")
  }
  if (is.null(alpha)) alpha <- x$alpha[1]
  x <- x[order(x$family, x$param), ]
  tp <- if (faceted) do.call(rbind, lapply(split(x, x$panel, drop = TRUE), function(z) cbind(tipping_point(z, alpha), panel = z$panel[1])))
        else tipping_point(x, alpha)
  tp <- tp[!is.na(tp$crossing), , drop = FALSE]
  anchor <- x[x$kind == "alternative", , drop = FALSE]
  g <- ggplot2::ggplot(x, ggplot2::aes(x = param, y = p, colour = family, group = family)) +
    ggplot2::geom_hline(yintercept = alpha, colour = PAL[["orange"]], linewidth = 1, linetype = "22") +
    ggplot2::geom_line(linewidth = 1.2) + ggplot2::geom_point(size = 2.5)
  if (nrow(anchor)) g <- g + ggplot2::geom_point(data = anchor, colour = PAL[["orange"]], size = 5)
  if (nrow(tp)) {
    tp$vj <- 1.5 + 1.4 * (stats::ave(seq_len(nrow(tp)), if (faceted) tp$panel else rep(1L, nrow(tp)), FUN = seq_along) - 1)   # stack the labels of several crossings in one panel
    g <- g + ggplot2::geom_vline(data = tp, ggplot2::aes(xintercept = crossing), colour = PAL[["ink2"]], linewidth = 0.5, linetype = "12") +
      ggplot2::geom_text(data = tp, ggplot2::aes(x = crossing, y = Inf, label = paste0("crosses at ", signif(crossing, 3)), vjust = vj),
                         inherit.aes = FALSE, colour = PAL[["ink"]], hjust = -0.05, size = 3.4)
  }
  AL <- if (faceted) stats::aggregate(list(param = x$param), list(panel = x$panel), min) else data.frame(param = min(x$param))
  g <- g + ggplot2::geom_text(data = AL, ggplot2::aes(x = param, y = alpha), label = paste("p =", alpha), inherit.aes = FALSE, colour = PAL[["orange"]], hjust = 0, vjust = -0.4, size = 3.4) +
    ggplot2::labs(x = xlab, y = ylab, colour = NULL) +
    ggplot2::scale_colour_manual(values = rep(c(PAL[["blue"]], PAL[["navy"]], PAL[["grey"]], PAL[["orange"]]), length.out = length(unique(x$family)))) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), legend.position = if (length(unique(x$family)) > 1) "bottom" else "none")
  if (log_p) g <- g + ggplot2::scale_y_log10()
  if (faceted) g <- g + ggplot2::facet_wrap(~ panel, ncol = ncol, scales = "free_x") +
    ggplot2::theme(strip.text = ggplot2::element_text(hjust = 0, face = "bold"))
  g
}

#' Strip plot of p-values after each deletion
#'
#' Each dot is one refit with one unit removed, on a p-value axis (linear by
#' default, log on request), one strip per leave-one-out family; the diamond is the pre-specified analysis
#' with nothing removed and the dashed line is alpha. Counts of deletions
#' below alpha label each strip.
#'
#' @param x A `stress_census`, a `stress_result`, or a list of them (one strip each).
#' @param alpha Significance level; defaults to the census's own.
#' @param log_p Draw the p-value axis on a log scale (spreads out the small
#'   p-values; harder to read for most audiences).
#' @param xmax Upper limit of the linear p-value axis; `NULL` fits the data.
#' @param label_family Include the deletion family in each strip label; set
#'   `FALSE` when every census contributes one family (subjects only, say).
#' @param highlight Optional labels of deletion rows (the removed unit, as in the
#'   census `label` column) to ring and label, for example the participant whose
#'   removal crosses alpha. Use [mask_ids()] first if identifiers must not appear.
#' @param seed Seed of the vertical scatter within each strip, so the figure is
#'   the same every time it is drawn; the caller's random-number state is
#'   restored on exit.
#' @return A `ggplot` object.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' cen <- stress_census(spec, stress_loo(spec, by = "RACE"), stress_loo(spec, by = "SEX"))
#' if (requireNamespace("ggplot2", quietly = TRUE)) {
#'   plot_pstrip(cen)
#'   plot_pstrip(cen, highlight = "Asian")
#' }
#' @export
plot_pstrip <- function(x, alpha = NULL, log_p = FALSE, xmax = NULL, label_family = TRUE, highlight = NULL, seed = 1L) {
  need_ggplot()
  cens <- as_census_list(x)
  d <- do.call(rbind, lapply(names(cens), function(nm) {
    ce <- cens[[nm]]; z <- as.data.frame(ce)[ce$counted & ce$kind == "deletion" & !is.na(ce$p), , drop = FALSE]
    if (!nrow(z)) return(NULL)
    data.frame(row = nm, strip = paste(nm, z$family, sep = " \u00b7 "), unit = z$label, p = z$p, base_p = attr(ce, "base")$p, a = attr(ce, "alpha"), stringsAsFactors = FALSE)
  }))
  if (is.null(d) || !nrow(d)) stop("no deletion rows to plot")
  if (is.null(alpha)) alpha <- d$a[1]
  order_strips <- unique(d$strip)   # input order: first census (and its first family) at the top
  lab <- do.call(rbind, lapply(order_strips, function(s) { g <- d[d$strip == s, ]; data.frame(strip = s, row = g$row[1], base_p = g$base_p[1], n = nrow(g), k = sum(g$p < alpha), stringsAsFactors = FALSE) }))
  lab$text <- sprintf("%s   %d / %d", if (label_family) lab$strip else lab$row, lab$k, lab$n)
  d$strip <- factor(d$strip, levels = rev(order_strips)); lab$strip <- factor(lab$strip, levels = levels(d$strip))
  # the scatter is drawn here rather than by geom_jitter(), so a highlighted dot can be ringed where it is drawn
  old_rng <- rng_state(); on.exit(rng_restore(old_rng), add = TRUE)
  if (!is.null(seed) && !is.na(seed)) seed_rng(seed)
  d$y <- as.numeric(d$strip) + stats::runif(nrow(d), -0.2, 0.2); lab$y <- as.numeric(lab$strip)
  hl <- if (is.null(highlight)) d[0, , drop = FALSE] else d[d$unit %in% highlight, , drop = FALSE]
  if (!is.null(highlight) && !nrow(hl)) warning("no deletion row has a label in `highlight`")
  g <- ggplot2::ggplot(d, ggplot2::aes(x = p, y = y)) +
    ggplot2::geom_vline(xintercept = alpha, colour = PAL[["ink2"]], linetype = "22") +
    ggplot2::geom_point(colour = PAL[["blue"]], alpha = 0.6, size = 1.8) +
    ggplot2::geom_point(data = lab, ggplot2::aes(x = base_p, y = y), shape = 23, fill = PAL[["orange"]], colour = PAL[["ink"]], size = 4) +
    { if (log_p) ggplot2::scale_x_log10() else ggplot2::scale_x_continuous(limits = c(0, if (is.null(xmax)) max(c(d$p, alpha * 1.5)) * 1.05 else xmax), expand = ggplot2::expansion(mult = c(0, 0.02))) } +
    ggplot2::scale_y_continuous(breaks = lab$y, labels = lab$text, limits = c(0.3, nlevels(d$strip) + 0.5), expand = c(0, 0)) +
    ggplot2::annotate("text", x = alpha, y = 0.4, label = paste("p =", alpha), colour = PAL[["ink2"]], hjust = -0.1, size = 3.2) +
    ggplot2::labs(x = paste0("Two-sided p-value after deleting one unit and refitting", if (log_p) " (log scale)" else ""), y = NULL) +
    ggplot2::theme_minimal(base_size = 11) + ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
  if (nrow(hl)) g <- g + ggplot2::geom_point(data = hl, shape = 21, fill = NA, colour = PAL[["ink"]], size = 4, stroke = 1) +
    ggplot2::geom_text(data = hl, ggplot2::aes(label = unit), colour = PAL[["ink"]], size = 3, hjust = -0.35, vjust = 0.5)
  g
}

utils::globalVariables(c("param", "p", "crossing", "x", "y", "yend", "id", "sig", "lab", "strip", "base_p", "ymin", "ymax", "row", "unit", "vj"))

#' Empirical distribution of the p-values across a census
#'
#' The empirical cumulative distribution of the p-values of every counted
#' refit, against the uniform diagonal that a result with no true effect
#' would produce (the p-value of each refit of a null result is uniform, so
#' the curve of a null census hugs the diagonal; a census far above it is
#' far from random). One curve per census when several are given, with the
#' pooled curve in black; the share below alpha is annotated.
#'
#' The refits are not independent, so the curve is a description, not a test.
#'
#' @param x A `stress_census`, a `stress_result`, the list from [run_plans()], or a list of censuses or results (one curve each).
#' @param alpha Significance level; defaults to the census's own.
#' @param pooled Draw the pooled curve over all censuses.
#' @return A `ggplot` object.
#' @examples
#' small <- mmrm::fev_data[mmrm::fev_data$USUBJID %in% paste0("PT", 1:60), ]
#' spec <- stress_spec(small, "FEV1", "USUBJID", "AVISIT", "ARMCD", "PBO", covariates = ~ FEV1_BL,
#'                     covariance = "cs", method = "Satterthwaite", vcov = "Asymptotic")
#' cen <- stress_census(spec, stress_covariance(spec, c("cs", "ar1h")), stress_loo(spec, by = "RACE"))
#' if (requireNamespace("ggplot2", quietly = TRUE)) plot_pcdf(cen)
#' @export
plot_pcdf <- function(x, alpha = NULL, pooled = TRUE) {
  need_ggplot()
  cens <- as_census_list(x)
  d <- do.call(rbind, lapply(names(cens), function(nm) { ce <- cens[[nm]]; z <- as.data.frame(ce)[ce$counted & !is.na(ce$p), , drop = FALSE]
    data.frame(row = nm, p = z$p, a = attr(ce, "alpha"), stringsAsFactors = FALSE) }))
  if (is.null(alpha)) alpha <- d$a[1]
  d$row <- factor(d$row, levels = names(cens))
  share <- mean(d$p < alpha)
  g <- ggplot2::ggplot() +
    ggplot2::geom_abline(intercept = 0, slope = 1, colour = PAL[["light"]], linewidth = 1, linetype = "22") +
    ggplot2::annotate("text", x = 0.72, y = 0.62, label = "no true effect:\np-values uniform", colour = PAL[["ink2"]], size = 3.2, hjust = 0, lineheight = 0.9) +
    ggplot2::geom_vline(xintercept = alpha, colour = PAL[["orange"]], linetype = "22")
  if (length(cens) > 1L) g <- g + ggplot2::stat_ecdf(data = d, ggplot2::aes(x = p, colour = row), geom = "step", linewidth = 0.9, pad = FALSE)
  if (pooled || length(cens) == 1L) g <- g + ggplot2::stat_ecdf(data = d, ggplot2::aes(x = p), geom = "step", colour = PAL[["ink"]], linewidth = if (length(cens) > 1L) 1.6 else 1.3, pad = FALSE)
  g <- g + ggplot2::annotate("text", x = alpha, y = 0.02, label = sprintf("%d%% of %d refits below %s", round(100 * share), nrow(d), format(alpha)), colour = PAL[["orange"]], hjust = -0.05, vjust = 0, size = 3.4) +
    ggplot2::scale_x_continuous(limits = c(0, 1), expand = c(0, 0)) + ggplot2::scale_y_continuous(limits = c(0, 1), expand = c(0, 0.01), labels = function(v) paste0(round(100 * v), "%")) +
    ggplot2::scale_colour_manual(values = rep(c(PAL[["blue"]], PAL[["orange"]], PAL[["navy"]], PAL[["grey"]], "#7a9e7e", "#b27bb0"), length.out = length(cens))) +
    ggplot2::labs(x = "Two-sided p-value of the refit", y = "Share of refits with a smaller p-value", colour = NULL) +
    ggplot2::coord_fixed() + ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), legend.position = if (length(cens) > 1L) "right" else "none")
  g
}
